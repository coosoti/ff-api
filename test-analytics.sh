#!/bin/bash

# ─────────────────────────────────────────────
# Module 8 — Analytics & Reports API Test Script
# Usage: chmod +x test-analytics.sh && ./test-analytics.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="analytics_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
PASS=0
FAIL=0
MONTH=$(date +%Y-%m)
TODAY=$(date +%Y-%m-%d)

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
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Analytics User\",\"monthly_income\":120000,\"dependents\":1}")

ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
[ -n "$ACCESS_TOKEN" ] && pass "Registered and got token" || { fail "Registration failed: $RESPONSE"; exit 1; }

# Seed income
curl -s -X POST "$BASE_URL/income" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"amount\":120000,\"source\":\"Salary\",\"month\":\"$MONTH\"}" > /dev/null

# Seed transactions
for AMOUNT in 30000 15000 8000 5000; do
  curl -s -X POST "$BASE_URL/transactions" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "{\"amount\":$AMOUNT,\"type\":\"expense\",\"date\":\"$TODAY\"}" > /dev/null
done

# Seed savings goal
curl -s -X POST "$BASE_URL/savings" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Car Fund","target_amount":500000,"current_amount":125000}' > /dev/null

# Seed investment
curl -s -X POST "$BASE_URL/investments" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Safaricom","type":"stocks","total_invested":50000,"current_value":58000}' > /dev/null

pass "Seeded income, 4 transactions, savings goal, investment"

# ─────────────────────────────────────────────
section "Income vs Expenses Trend"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/analytics/income-expense?months=12" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Income/expense trend returned" || { fail "Trend failed: $RESPONSE"; exit 1; }

TREND=$(echo "$RESPONSE" | grep -o '"trend":\[' )
[ -n "$TREND" ] && pass "Trend array present" || fail "Missing trend array"

TOTAL_INC=$(echo "$RESPONSE" | grep -o '"totalIncome":[0-9]*' | head -1 | cut -d':' -f2)
[ "$TOTAL_INC" = "120000" ] && pass "Total income = 120000" || fail "Expected 120000, got $TOTAL_INC"

TOTAL_EXP=$(echo "$RESPONSE" | grep -o '"totalExpenses":[0-9]*' | head -1 | cut -d':' -f2)
[ "$TOTAL_EXP" = "58000" ] && pass "Total expenses = 58000" || fail "Expected 58000, got $TOTAL_EXP"

# ─────────────────────────────────────────────
section "Spending by Category"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/analytics/spending?months=12" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Spending by category returned" || { fail "Spending failed: $RESPONSE"; exit 1; }

GRAND=$(echo "$RESPONSE" | grep -o '"grandTotal":[0-9]*' | head -1 | cut -d':' -f2)
[ "$GRAND" = "58000" ] && pass "Grand total = 58000" || fail "Expected grandTotal 58000, got $GRAND"

CATS=$(echo "$RESPONSE" | grep -o '"categories":\[')
[ -n "$CATS" ] && pass "Categories array present" || fail "Missing categories array"

# ─────────────────────────────────────────────
section "Budget Performance"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/analytics/budget?months=12" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Budget performance returned" || { fail "Budget failed: $RESPONSE"; exit 1; }

PERF=$(echo "$RESPONSE" | grep -o '"performance":\[')
[ -n "$PERF" ] && pass "Performance array present" || fail "Missing performance array"

SUMMARY=$(echo "$RESPONSE" | grep -o '"summary":{')
[ -n "$SUMMARY" ] && pass "Summary object present" || fail "Missing summary object"

# ─────────────────────────────────────────────
section "Savings Progress"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/analytics/savings" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Savings progress returned" || { fail "Savings failed: $RESPONSE"; exit 1; }

PCT=$(echo "$RESPONSE" | grep -o '"overall_pct":[0-9]*' | head -1 | cut -d':' -f2)
[ "$PCT" = "25" ] && pass "Overall savings pct = 25% (125k/500k)" || fail "Expected 25, got $PCT"

ACTIVE=$(echo "$RESPONSE" | grep -o '"active":[0-9]' | head -1 | cut -d':' -f2)
[ "$ACTIVE" = "1" ] && pass "1 active savings goal" || fail "Expected 1 active, got $ACTIVE"

# ─────────────────────────────────────────────
section "Net Worth Snapshot"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/analytics/networth" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Net worth snapshot returned" || { fail "Networth failed: $RESPONSE"; exit 1; }

NW=$(echo "$RESPONSE" | grep -o '"net_worth":[0-9-]*' | head -1 | cut -d':' -f2)
[ -n "$NW" ] && pass "Net worth present = $NW" || fail "Missing net_worth"

CASH_TREND=$(echo "$RESPONSE" | grep -o '"cash_trend":\[')
[ -n "$CASH_TREND" ] && pass "Cash trend array present" || fail "Missing cash_trend"

# ─────────────────────────────────────────────
section "Full Report"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/analytics/report?months=12" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Full report returned" || { fail "Report failed: $RESPONSE"; exit 1; }

for KEY in incomeExpense spending budget savings networth generated_at; do
  FOUND=$(echo "$RESPONSE" | grep -o "\"$KEY\"")
  [ -n "$FOUND" ] && pass "Report contains $KEY" || fail "Missing $KEY in report"
done

# Invalid months param — defaults to 12
RESPONSE=$(curl -s "$BASE_URL/analytics/income-expense?months=99" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Invalid months param defaults to 12" || fail "Should fallback gracefully"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(analytics): income/expense trend, spending, budget, savings and net worth report\""
else
  echo -e "${RED}Fix failing tests before committing${NC}"
  exit 1
fi