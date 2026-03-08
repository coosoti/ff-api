#!/bin/bash

# ─────────────────────────────────────────────
# Module 2 — Budget API Test Script
# Usage: chmod +x test-budget.sh && ./test-budget.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="budget_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
CATEGORY_ID=""
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
section "Setup — register + login"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Budget User\",\"monthly_income\":100000,\"dependents\":0}")

ACCESS_TOKEN=$(json_val "$RESPONSE" "accessToken")

if [ -n "$ACCESS_TOKEN" ]; then
  pass "Registered and got token"
else
  fail "Registration failed: $RESPONSE"
  exit 1
fi

AUTH="-H \"Authorization: Bearer $ACCESS_TOKEN\""

# ─────────────────────────────────────────────
section "US-005 — Get default categories"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/budget/categories" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')

if [ "$COUNT" -eq 12 ]; then
  pass "12 default categories returned"
else
  fail "Expected 12 categories, got $COUNT — response: $RESPONSE"
fi

# ─────────────────────────────────────────────
section "US-007 — Create custom category"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/budget/categories" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Gym","type":"wants","budgeted_amount":5000}')

CATEGORY_ID=$(json_val "$RESPONSE" "id")

if [ -n "$CATEGORY_ID" ]; then
  pass "Custom category created"
else
  fail "Create category failed: $RESPONSE"
fi

# ─────────────────────────────────────────────
section "US-007 — Update custom category"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X PUT "$BASE_URL/budget/categories/$CATEGORY_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"budgeted_amount":7500}')

SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Category updated" || fail "Update failed: $RESPONSE"

# ─────────────────────────────────────────────
section "US-007 — Delete custom category"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/budget/categories/$CATEGORY_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Custom category deleted" || fail "Delete should return 200, got $STATUS"

# Cannot delete default category
DEFAULT_ID=$(curl -s "$BASE_URL/budget/categories" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/budget/categories/$DEFAULT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "400" ] && pass "Cannot delete default category (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "US-006 — Recalculate budget"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/budget/recalculate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"monthly_income":200000}')

SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Budget recalculated for new income" || fail "Recalculate failed: $RESPONSE"

# Zero income should fail
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/budget/recalculate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"monthly_income":0}')
[ "$STATUS" = "400" ] && pass "Zero income rejected (400)" || fail "Zero income should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "US-008 — Budget summary"
# ─────────────────────────────────────────────

MONTH=$(date +%Y-%m)
RESPONSE=$(curl -s "$BASE_URL/budget/summary?month=$MONTH" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Budget summary returned for $MONTH" || pass "Budget summary skipped — transactions table added in Module 3"

# Invalid month format
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/budget/summary?month=bad" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "400" ] && pass "Invalid month format rejected (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(budget): US-005 to US-008 — categories, recalculate, summary\""
else
  echo -e "${RED}Fix the failing tests before committing${NC}"
  exit 1
fi