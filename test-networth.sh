#!/bin/bash

# ─────────────────────────────────────────────
# Module 5 — Net Worth API Test Script
# Usage: chmod +x test-networth.sh && ./test-networth.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="networth_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
ASSET_ID=""
LIABILITY_ID=""
PASS=0
FAIL=0
MONTH=$(date +%Y-%m)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}✗ $1${NC}"; FAIL=$((FAIL+1)); }
section() { echo -e "\n${YELLOW}── $1 ──${NC}"; sleep 0.5; }

# ─────────────────────────────────────────────
section "Setup — register + seed data"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"NW User\",\"monthly_income\":100000,\"dependents\":0}")

ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
[ -n "$ACCESS_TOKEN" ] && pass "Registered and got token" || { fail "Registration failed: $RESPONSE"; exit 1; }

# Seed income
curl -s -X POST "$BASE_URL/income" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":100000,\"source\":\"Salary\",\"month\":\"$MONTH\"}" > /dev/null

# Seed expense
curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":40000,\"type\":\"expense\",\"date\":\"$(date +%Y-%m-%d)\",\"notes\":\"Rent\"}" > /dev/null

# Seed savings goal
curl -s -X POST "$BASE_URL/savings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Emergency Fund","target_amount":300000,"current_amount":50000}' > /dev/null

pass "Seeded income (100k), expense (40k), savings (50k)"

# ─────────────────────────────────────────────
section "Assets — CRUD"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/networth/assets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Toyota Fielder","category":"vehicle","value":1500000,"notes":"2019 model"}')
ASSET_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$ASSET_ID" ] && pass "Asset created (vehicle 1.5M)" || { fail "Asset create failed: $RESPONSE"; exit 1; }

# Second asset
curl -s -X POST "$BASE_URL/networth/assets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Land Kiambu","category":"property","value":5000000}' > /dev/null
pass "Second asset created (property 5M)"

# Get all assets
RESPONSE=$(curl -s "$BASE_URL/networth/assets" -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 2 ] && pass "Got $COUNT assets" || fail "Expected 2+ assets, got $COUNT"

# Update asset
RESPONSE=$(curl -s -X PUT "$BASE_URL/networth/assets/$ASSET_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"value":1400000,"notes":"2019 model - depreciated"}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Asset updated (value 1.4M)" || fail "Asset update failed: $RESPONSE"

# Invalid category
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/networth/assets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Bad","category":"crypto","value":1000}')
[ "$STATUS" = "400" ] && pass "Invalid category rejected (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "Liabilities — CRUD"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/networth/liabilities" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"NCBA Car Loan","category":"loan","balance":800000,"interest_rate":14.5}')
LIABILITY_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$LIABILITY_ID" ] && pass "Liability created (loan 800k)" || { fail "Liability create failed: $RESPONSE"; exit 1; }

# Second liability
curl -s -X POST "$BASE_URL/networth/liabilities" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"KCB Credit Card","category":"credit_card","balance":45000}' > /dev/null
pass "Second liability created (credit card 45k)"

# Get all liabilities
RESPONSE=$(curl -s "$BASE_URL/networth/liabilities" -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 2 ] && pass "Got $COUNT liabilities" || fail "Expected 2+ liabilities, got $COUNT"

# Update liability
RESPONSE=$(curl -s -X PUT "$BASE_URL/networth/liabilities/$LIABILITY_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"balance":750000}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Liability updated (balance 750k)" || fail "Liability update failed: $RESPONSE"

# ─────────────────────────────────────────────
section "Net Worth Summary"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/networth" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Net worth summary returned" || { fail "Summary failed: $RESPONSE"; exit 1; }

# cash = 100000 - 40000 - 50000 (savings) = 10000
CASH=$(echo "$RESPONSE" | grep -o '"cash":[0-9]*' | cut -d':' -f2)
[ "$CASH" = "10000" ] && pass "Cash balance = 10000 (income 100k - expenses 40k - savings 50k)" || fail "Expected cash 10000, got $CASH"

# savings = 50000
SAVINGS=$(echo "$RESPONSE" | grep -o '"savings":[0-9]*' | cut -d':' -f2)
[ "$SAVINGS" = "50000" ] && pass "Savings = 50000 from goals" || fail "Expected savings 50000, got $SAVINGS"

# total liabilities = 750000 + 45000 = 795000
LIAB=$(echo "$RESPONSE" | grep -o '"total_liabilities":[0-9]*' | cut -d':' -f2)
[ "$LIAB" = "795000" ] && pass "Total liabilities = 795000" || fail "Expected 795000, got $LIAB"

# net worth = (10000 + 50000 + 1400000 + 5000000) - 795000 = 5665000
NW=$(echo "$RESPONSE" | grep -o '"net_worth":[0-9-]*' | cut -d':' -f2)
[ "$NW" = "5665000" ] && pass "Net worth = 5,665,000" || fail "Expected 5665000, got $NW"

# ─────────────────────────────────────────────
section "Delete asset and liability"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/networth/assets/$ASSET_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Asset deleted" || fail "Delete should return 200, got $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/networth/liabilities/$LIABILITY_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Liability deleted" || fail "Delete should return 200, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(networth): assets, liabilities and hybrid net worth summary\""
else
  echo -e "${RED}Fix failing tests before committing${NC}"
  exit 1
fi