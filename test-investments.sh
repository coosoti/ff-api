#!/bin/bash

# ─────────────────────────────────────────────
# Module 6 — Investments API Test Script
# Usage: chmod +x test-investments.sh && ./test-investments.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="invest_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
INVESTMENT_ID=""
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
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Investor\",\"monthly_income\":200000,\"dependents\":0}")

ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
[ -n "$ACCESS_TOKEN" ] && pass "Registered and got token" || { fail "Registration failed: $RESPONSE"; exit 1; }

# ─────────────────────────────────────────────
section "Create investments"
# ─────────────────────────────────────────────

# Safaricom shares
RESPONSE=$(curl -s -X POST "$BASE_URL/investments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Safaricom PLC",
    "type": "stocks",
    "institution": "CDSC",
    "units": 1000,
    "purchase_price": 28.50,
    "current_price": 32.00,
    "total_invested": 28500,
    "current_value": 32000,
    "purchase_date": "2025-01-15",
    "notes": "NSE listed"
  }')
INVESTMENT_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$INVESTMENT_ID" ] && pass "Stocks investment created" || { fail "Create failed: $RESPONSE"; exit 1; }

# MMF
RESPONSE=$(curl -s -X POST "$BASE_URL/investments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Nabo Capital MMF",
    "type": "mmf",
    "institution": "Nabo Capital",
    "total_invested": 50000,
    "current_value": 53200,
    "notes": "Monthly contributions"
  }')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "MMF investment created" || fail "MMF create failed: $RESPONSE"

# Bonds
RESPONSE=$(curl -s -X POST "$BASE_URL/investments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Kenya Government Bond",
    "type": "bonds",
    "institution": "CBK",
    "total_invested": 100000,
    "current_value": 100000
  }')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Bond investment created" || fail "Bond create failed: $RESPONSE"

# Invalid type
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/investments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Bad","type":"nft","total_invested":1000,"current_value":1000}')
[ "$STATUS" = "400" ] && pass "Invalid type rejected (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "Get investments"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/investments" -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 3 ] && pass "Got $COUNT investments" || fail "Expected 3+, got $COUNT"

RESPONSE=$(curl -s "$BASE_URL/investments/$INVESTMENT_ID" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Get by id works" || fail "Get by id failed: $RESPONSE"

# ─────────────────────────────────────────────
section "Portfolio summary"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/investments/portfolio" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Portfolio summary returned" || { fail "Portfolio failed: $RESPONSE"; exit 1; }

# total_invested = 28500 + 50000 + 100000 = 178500
TOTAL_INV=$(echo "$RESPONSE" | grep -o '"total_invested":[0-9]*' | head -1 | cut -d':' -f2)
[ "$TOTAL_INV" = "178500" ] && pass "Total invested = 178500" || fail "Expected 178500, got $TOTAL_INV"

# total_current_value = 32000 + 53200 + 100000 = 185200
TOTAL_VAL=$(echo "$RESPONSE" | grep -o '"total_current_value":[0-9]*' | cut -d':' -f2)
[ "$TOTAL_VAL" = "185200" ] && pass "Total current value = 185200" || fail "Expected 185200, got $TOTAL_VAL"

# gain/loss = 185200 - 178500 = 6700
GAIN=$(echo "$RESPONSE" | grep -o '"total_gain_loss":[0-9]*' | cut -d':' -f2)
[ "$GAIN" = "6700" ] && pass "Total gain = 6700" || fail "Expected 6700, got $GAIN"

# by_type should include stocks, mmf, bonds
STOCKS=$(echo "$RESPONSE" | grep -o '"stocks"')
MMF=$(echo "$RESPONSE" | grep -o '"mmf"')
[ -n "$STOCKS" ] && pass "Portfolio grouped by stocks" || fail "Missing stocks in by_type"
[ -n "$MMF" ]    && pass "Portfolio grouped by mmf" || fail "Missing mmf in by_type"

# ─────────────────────────────────────────────
section "Update investment"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X PUT "$BASE_URL/investments/$INVESTMENT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"current_price":35.00,"current_value":35000}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Investment updated (price 35.00)" || fail "Update failed: $RESPONSE"

# ─────────────────────────────────────────────
section "Delete investment"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/investments/$INVESTMENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Investment deleted" || fail "Delete should return 200, got $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/investments/$INVESTMENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "404" ] && pass "Deleted investment returns 404" || fail "Should return 404, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(investments): portfolio tracking with gain/loss and type breakdown\""
else
  echo -e "${RED}Fix failing tests before committing${NC}"
  exit 1
fi