#!/bin/bash

# ─────────────────────────────────────────────
# Income Module — API Test Script
# Usage: chmod +x test-income.sh && ./test-income.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="income_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
INCOME_ID=""
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

MONTH=$(date +%Y-%m)

# ─────────────────────────────────────────────
section "Setup — register"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Income User\",\"monthly_income\":100000,\"dependents\":0}")

ACCESS_TOKEN=$(json_val "$RESPONSE" "accessToken")

if [ -n "$ACCESS_TOKEN" ]; then
  pass "Registered and got token"
else
  fail "Registration failed: $RESPONSE"
  exit 1
fi

# ─────────────────────────────────────────────
section "Create income entries"
# ─────────────────────────────────────────────

# Add salary
RESPONSE=$(curl -s -X POST "$BASE_URL/income" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":100000,\"source\":\"Salary\",\"month\":\"$MONTH\",\"notes\":\"Monthly salary\"}")
INCOME_ID=$(json_val "$RESPONSE" "id")
[ -n "$INCOME_ID" ] && pass "Salary income created (id: $INCOME_ID)" || fail "Salary create failed: $RESPONSE"

# Add freelance
RESPONSE=$(curl -s -X POST "$BASE_URL/income" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":30000,\"source\":\"Freelance\",\"month\":\"$MONTH\",\"notes\":\"Design project\"}")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Freelance income created" || fail "Freelance create failed: $RESPONSE"

# Invalid — negative amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/income" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":-500,\"source\":\"Salary\",\"month\":\"$MONTH\"}")
[ "$STATUS" = "400" ] && pass "Negative amount rejected (400)" || fail "Should return 400, got $STATUS"

# Invalid — bad month format
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/income" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":1000,\"source\":\"Salary\",\"month\":\"March-2026\"}")
[ "$STATUS" = "400" ] && pass "Bad month format rejected (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "Get income by month"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/income?month=$MONTH" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
TOTAL=$(echo "$RESPONSE" | grep -o '"total":[0-9]*' | cut -d':' -f2)
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')

[ "$COUNT" -ge 2 ] && pass "Got $COUNT income entries" || fail "Expected 2+ entries, got $COUNT"
[ "$TOTAL" = "130000" ] && pass "Total is 130000 (100000 + 30000)" || fail "Expected total 130000, got $TOTAL"

# ─────────────────────────────────────────────
section "Update income"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X PUT "$BASE_URL/income/$INCOME_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"amount":110000,"notes":"Salary + bonus"}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Income updated" || fail "Update failed: $RESPONSE"

# Verify total updated
RESPONSE=$(curl -s "$BASE_URL/income?month=$MONTH" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
TOTAL=$(echo "$RESPONSE" | grep -o '"total":[0-9]*' | cut -d':' -f2)
[ "$TOTAL" = "140000" ] && pass "Total updated to 140000 after edit" || fail "Expected 140000, got $TOTAL"

# ─────────────────────────────────────────────
section "Budget summary uses income table"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/budget/summary?month=$MONTH" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
SUMMARY_INCOME=$(echo "$RESPONSE" | grep -o '"total_income":[0-9]*' | cut -d':' -f2)
[ "$SUMMARY_INCOME" = "140000" ] && pass "Budget summary total_income = 140000" || fail "Expected 140000, got $SUMMARY_INCOME"

# ─────────────────────────────────────────────
section "Delete income"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/income/$INCOME_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Income entry deleted" || fail "Delete should return 200, got $STATUS"

# Verify total dropped
RESPONSE=$(curl -s "$BASE_URL/income?month=$MONTH" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
TOTAL=$(echo "$RESPONSE" | grep -o '"total":[0-9]*' | cut -d':' -f2)
[ "$TOTAL" = "30000" ] && pass "Total dropped to 30000 after delete" || fail "Expected 30000, got $TOTAL"

# ─────────────────────────────────────────────
section "Fallback — no income logged returns profile monthly_income"
# ─────────────────────────────────────────────

PREV_MONTH=$(date -d "1 month ago" +%Y-%m 2>/dev/null || date -v-1m +%Y-%m)
RESPONSE=$(curl -s "$BASE_URL/income?month=$PREV_MONTH" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
TOTAL=$(echo "$RESPONSE" | grep -o '"total":[0-9]*' | cut -d':' -f2)
[ "$TOTAL" = "100000" ] && pass "Fallback to profile monthly_income (100000)" || fail "Expected fallback 100000, got $TOTAL"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(income): dedicated income module — salary + additional income per month\""
else
  echo -e "${RED}Fix failing tests before committing${NC}"
  exit 1
fi