#!/bin/bash

# ─────────────────────────────────────────────
# Module 7 — IPP Pension API Test Script
# Usage: chmod +x test-pension.sh && ./test-pension.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="pension_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
ACCOUNT_ID=""
WITHDRAWAL_ID=""
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}✗ $1${NC}"; FAIL=$((FAIL+1)); }
section() { echo -e "\n${YELLOW}── $1 ──${NC}"; sleep 0.5; }

# ─────────────────────────────────────────────
section "Setup — register"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Pension User\",\"monthly_income\":150000,\"dependents\":2}")

ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
[ -n "$ACCESS_TOKEN" ] && pass "Registered and got token" || { fail "Registration failed: $RESPONSE"; exit 1; }

# ─────────────────────────────────────────────
section "Pension Accounts — CRUD"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/pension" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "provider": "Jubilee Insurance",
    "scheme_name": "Individual Pension Plan",
    "total_value": 500000,
    "retirement_age": 60,
    "date_of_birth": "1985-06-15",
    "notes": "Main IPP account"
  }')
ACCOUNT_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$ACCOUNT_ID" ] && pass "Pension account created" || { fail "Create failed: $RESPONSE"; exit 1; }

# Get all accounts
RESPONSE=$(curl -s "$BASE_URL/pension" -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 1 ] && pass "Got $COUNT pension account(s)" || fail "Expected 1+ accounts, got $COUNT"

# Get by id
RESPONSE=$(curl -s "$BASE_URL/pension/$ACCOUNT_ID" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Get account by id works" || fail "Get by id failed: $RESPONSE"

# Update account
RESPONSE=$(curl -s -X PUT "$BASE_URL/pension/$ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"total_value":520000,"notes":"Updated value after Q1 statement"}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Account updated (520k)" || fail "Update failed: $RESPONSE"

# Invalid retirement age
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/pension" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"provider":"X","scheme_name":"Y","total_value":1000,"retirement_age":40}')
[ "$STATUS" = "400" ] && pass "Retirement age < 50 rejected (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "Fund Allocations"
# ─────────────────────────────────────────────

# Valid allocation summing to 100%
RESPONSE=$(curl -s -X PUT "$BASE_URL/pension/$ACCOUNT_ID/funds" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "funds": [
      {"name": "Money Market Fund", "allocation_pct": 40, "current_value": 208000},
      {"name": "Balanced Fund",     "allocation_pct": 35, "current_value": 182000},
      {"name": "Equity Fund",       "allocation_pct": 25, "current_value": 130000}
    ]
  }')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Fund allocations saved (40/35/25)" || fail "Funds upsert failed: $RESPONSE"

# Get funds
RESPONSE=$(curl -s "$BASE_URL/pension/$ACCOUNT_ID/funds" -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -eq 3 ] && pass "Got 3 funds" || fail "Expected 3 funds, got $COUNT"

# Invalid allocation not summing to 100
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE_URL/pension/$ACCOUNT_ID/funds" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "funds": [
      {"name": "MMF", "allocation_pct": 60, "current_value": 300000},
      {"name": "Equity", "allocation_pct": 20, "current_value": 100000}
    ]
  }')
[ "$STATUS" = "400" ] && pass "Allocations not summing to 100% rejected" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "Withdrawals"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/pension/$ACCOUNT_ID/withdrawals" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":20000,\"reason\":\"Partial withdrawal\",\"date\":\"$(date +%Y-%m-%d)\",\"notes\":\"Medical emergency\"}")
WITHDRAWAL_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$WITHDRAWAL_ID" ] && pass "Withdrawal created (20k)" || { fail "Withdrawal create failed: $RESPONSE"; exit 1; }

# Check account value decreased
RESPONSE=$(curl -s "$BASE_URL/pension/$ACCOUNT_ID" -H "Authorization: Bearer $ACCESS_TOKEN")
VALUE=$(echo "$RESPONSE" | grep -o '"total_value":[0-9]*' | head -1 | cut -d':' -f2)
[ "$VALUE" = "500000" ] && pass "Account value decreased to 500000 after withdrawal" || fail "Expected 500000, got $VALUE"

# Get withdrawals
RESPONSE=$(curl -s "$BASE_URL/pension/$ACCOUNT_ID/withdrawals" -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 1 ] && pass "Got $COUNT withdrawal(s)" || fail "Expected 1+ withdrawals, got $COUNT"

# Withdrawal exceeding balance
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/pension/$ACCOUNT_ID/withdrawals" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":9999999,\"date\":\"$(date +%Y-%m-%d)\"}")
[ "$STATUS" = "400" ] && pass "Withdrawal exceeding balance rejected (400)" || fail "Should return 400, got $STATUS"

# Delete withdrawal — amount should be restored
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  "$BASE_URL/pension/$ACCOUNT_ID/withdrawals/$WITHDRAWAL_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Withdrawal deleted" || fail "Delete should return 200, got $STATUS"

RESPONSE=$(curl -s "$BASE_URL/pension/$ACCOUNT_ID" -H "Authorization: Bearer $ACCESS_TOKEN")
VALUE=$(echo "$RESPONSE" | grep -o '"total_value":[0-9]*' | head -1 | cut -d':' -f2)
[ "$VALUE" = "520000" ] && pass "Account value restored to 520000 after withdrawal deletion" || fail "Expected 520000, got $VALUE"

# ─────────────────────────────────────────────
section "Projection"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/pension/$ACCOUNT_ID/projection" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Projection returned" || { fail "Projection failed: $RESPONSE"; exit 1; }

CONSERVATIVE=$(echo "$RESPONSE" | grep -o '"conservative":{[^}]*}' | grep -o '"value":[0-9]*' | cut -d':' -f2)
MODERATE=$(echo "$RESPONSE" | grep -o '"moderate":{[^}]*}' | grep -o '"value":[0-9]*' | cut -d':' -f2)
AGGRESSIVE=$(echo "$RESPONSE" | grep -o '"aggressive":{[^}]*}' | grep -o '"value":[0-9]*' | cut -d':' -f2)

[ -n "$CONSERVATIVE" ] && pass "Conservative projection = KES $CONSERVATIVE" || fail "Missing conservative projection"
[ -n "$MODERATE" ]     && pass "Moderate projection = KES $MODERATE"     || fail "Missing moderate projection"
[ -n "$AGGRESSIVE" ]   && pass "Aggressive projection = KES $AGGRESSIVE"   || fail "Missing aggressive projection"

# Aggressive should always be highest
if [ -n "$CONSERVATIVE" ] && [ -n "$AGGRESSIVE" ]; then
  [ "$AGGRESSIVE" -gt "$CONSERVATIVE" ] && pass "Aggressive > conservative projection" || fail "Aggressive should be greater than conservative"
fi

# ─────────────────────────────────────────────
section "Delete account"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/pension/$ACCOUNT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Account deleted" || fail "Delete should return 200, got $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/pension/$ACCOUNT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "404" ] && pass "Deleted account returns 404" || fail "Should return 404, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(pension): IPP pension with fund allocation, withdrawals and projection\""
else
  echo -e "${RED}Fix failing tests before committing${NC}"
  exit 1
fi