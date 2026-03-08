#!/bin/bash

# ─────────────────────────────────────────────
# Module 3 — Transactions API Test Script
# Usage: chmod +x test-transactions.sh && ./test-transactions.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="txn_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
CATEGORY_ID=""
TRANSACTION_ID=""
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; ((PASS++)); }
fail() { echo -e "${RED}✗ $1${NC}"; ((FAIL++)); }
section() { echo -e "\n${YELLOW}── $1 ──${NC}"; sleep 0.5; }
json_val() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

# ─────────────────────────────────────────────
section "Setup — register + get category"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Txn User\",\"monthly_income\":100000,\"dependents\":0}")

ACCESS_TOKEN=$(json_val "$RESPONSE" "accessToken")

if [ -n "$ACCESS_TOKEN" ]; then
  pass "Registered and got token"
else
  fail "Registration failed: $RESPONSE"
  exit 1
fi

# Get first category id to use in transactions
CAT_RESPONSE=$(curl -s "$BASE_URL/budget/categories" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
CATEGORY_ID=$(echo "$CAT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$CATEGORY_ID" ]; then
  pass "Got category id: $CATEGORY_ID"
else
  fail "Could not get category: $CAT_RESPONSE"
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)

# ─────────────────────────────────────────────
section "US-009 — Create transaction"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"category_id\":\"$CATEGORY_ID\",\"amount\":5000,\"type\":\"expense\",\"date\":\"$TODAY\",\"notes\":\"Test expense\"}")

TRANSACTION_ID=$(json_val "$RESPONSE" "id")
[ -n "$TRANSACTION_ID" ] && pass "Expense transaction created" || fail "Create failed: $RESPONSE"

# Create income transaction
RESPONSE=$(curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":50000,\"type\":\"income\",\"date\":\"$TODAY\",\"notes\":\"Salary\"}")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Income transaction created" || fail "Income create failed: $RESPONSE"

# Invalid amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":-100,\"type\":\"expense\",\"date\":\"$TODAY\"}")
[ "$STATUS" = "400" ] && pass "Negative amount rejected (400)" || fail "Should return 400, got $STATUS"

# Invalid date
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":100,\"type\":\"expense\",\"date\":\"bad-date\"}")
[ "$STATUS" = "400" ] && pass "Invalid date rejected (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "US-010 — Get transactions"
# ─────────────────────────────────────────────

# Get all
RESPONSE=$(curl -s "$BASE_URL/transactions" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Get all transactions" || fail "Get all failed: $RESPONSE"

# Get by month
RESPONSE=$(curl -s "$BASE_URL/transactions?month=$MONTH" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 2 ] && pass "Get by month returns $COUNT transactions" || fail "Expected 2+, got $COUNT"

# Get by id
RESPONSE=$(curl -s "$BASE_URL/transactions/$TRANSACTION_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Get by id" || fail "Get by id failed: $RESPONSE"

# ─────────────────────────────────────────────
section "US-010 — Update transaction"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X PUT "$BASE_URL/transactions/$TRANSACTION_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"amount":7500,"notes":"Updated expense"}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Transaction updated" || fail "Update failed: $RESPONSE"

# ─────────────────────────────────────────────
section "US-011 — Delete transaction"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/transactions/$TRANSACTION_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Transaction deleted" || fail "Delete should return 200, got $STATUS"

# Verify it's gone
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/transactions/$TRANSACTION_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "404" ] && pass "Deleted transaction returns 404" || fail "Should return 404, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(transactions): US-009 to US-011 — create, read, update, delete + socket.io broadcast\""
else
  echo -e "${RED}Fix the failing tests before committing${NC}"
  exit 1
fi