#!/bin/bash

# ─────────────────────────────────────────────
# Module 9 — Recurring Bills API Test Script
# Usage: chmod +x test-bills.sh && ./test-bills.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="bills_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
BILL_ID=""
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
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Bills User\",\"monthly_income\":100000,\"dependents\":0}")

ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
[ -n "$ACCESS_TOKEN" ] && pass "Registered and got token" || { fail "Registration failed: $RESPONSE"; exit 1; }

# ─────────────────────────────────────────────
section "Bills — CRUD"
# ─────────────────────────────────────────────

# Create rent bill
RESPONSE=$(curl -s -X POST "$BASE_URL/bills" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Rent","amount":25000,"category":"rent","cycle":"monthly","due_day":1}')
BILL_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$BILL_ID" ] && pass "Rent bill created (25k/month due day 1)" || { fail "Create failed: $RESPONSE"; exit 1; }

# Netflix subscription
RESPONSE=$(curl -s -X POST "$BASE_URL/bills" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Netflix","amount":1100,"category":"subscription","cycle":"monthly","due_day":15,"notes":"Family plan"}')
SUB_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$SUB_ID" ] && pass "Netflix subscription created (1100/month)" || fail "Subscription create failed: $RESPONSE"

# Annual insurance
RESPONSE=$(curl -s -X POST "$BASE_URL/bills" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Car Insurance","amount":45000,"category":"insurance","cycle":"annual","due_day":1}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Annual insurance created (45k/year)" || fail "Annual create failed: $RESPONSE"

# Invalid category
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/bills" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"X","amount":100,"category":"food","cycle":"monthly","due_day":1}')
[ "$STATUS" = "400" ] && pass "Invalid category rejected (400)" || fail "Should return 400, got $STATUS"

# Invalid due_day
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/bills" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"X","amount":100,"category":"other","cycle":"monthly","due_day":32}')
[ "$STATUS" = "400" ] && pass "due_day > 31 rejected (400)" || fail "Should return 400, got $STATUS"

# Get all bills
RESPONSE=$(curl -s "$BASE_URL/bills" -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 3 ] && pass "Got $COUNT bills" || fail "Expected 3+ bills, got $COUNT"

# next_due_date present
NEXT=$(echo "$RESPONSE" | grep -o '"next_due_date":"[^"]*"' | head -1)
[ -n "$NEXT" ] && pass "next_due_date present on bill" || fail "Missing next_due_date"

# is_paid present and false by default
PAID=$(echo "$RESPONSE" | grep -o '"is_paid":false' | head -1)
[ -n "$PAID" ] && pass "is_paid defaults to false" || fail "Missing is_paid:false"

# Update bill
RESPONSE=$(curl -s -X PUT "$BASE_URL/bills/$BILL_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"amount":27000,"notes":"Rent increase"}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Bill updated (27k)" || fail "Update failed: $RESPONSE"

# ─────────────────────────────────────────────
section "Pay & Unpay"
# ─────────────────────────────────────────────

# Mark rent as paid
RESPONSE=$(curl -s -X POST "$BASE_URL/bills/$BILL_ID/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"notes":"Paid via M-Pesa"}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Rent marked as paid" || fail "Mark paid failed: $RESPONSE"

# Check is_paid = true
RESPONSE=$(curl -s "$BASE_URL/bills" -H "Authorization: Bearer $ACCESS_TOKEN")
PAID_TRUE=$(echo "$RESPONSE" | grep -o '"is_paid":true' | head -1)
[ -n "$PAID_TRUE" ] && pass "is_paid = true after marking paid" || fail "Expected is_paid:true"

# Idempotent — pay again should not error
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/bills/$BILL_ID/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{}')
[ "$STATUS" = "200" ] && pass "Paying again is idempotent (200)" || fail "Should return 200, got $STATUS"

# Unpay
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/bills/$BILL_ID/pay" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Rent unpaid successfully" || fail "Unpay should return 200, got $STATUS"

# Check is_paid = false again
RESPONSE=$(curl -s "$BASE_URL/bills" -H "Authorization: Bearer $ACCESS_TOKEN")
PAID_FALSE=$(echo "$RESPONSE" | grep -o '"is_paid":false' | head -1)
[ -n "$PAID_FALSE" ] && pass "is_paid = false after unpay" || fail "Expected is_paid:false after unpay"

# ─────────────────────────────────────────────
section "Payment History"
# ─────────────────────────────────────────────

# Pay once so there's history
curl -s -X POST "$BASE_URL/bills/$BILL_ID/pay" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{}' > /dev/null

RESPONSE=$(curl -s "$BASE_URL/bills/$BILL_ID/history" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Payment history returned" || fail "History failed: $RESPONSE"

COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 1 ] && pass "Got $COUNT payment record(s) in history" || fail "Expected 1+ history records"

# ─────────────────────────────────────────────
section "Summary"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/bills/summary" -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Bills summary returned" || { fail "Summary failed: $RESPONSE"; exit 1; }

TOTAL_DUE=$(echo "$RESPONSE" | grep -o '"total_due":[0-9]*' | head -1 | cut -d':' -f2)
[ -n "$TOTAL_DUE" ] && pass "total_due present = $TOTAL_DUE" || fail "Missing total_due"

TOTAL_PAID=$(echo "$RESPONSE" | grep -o '"total_paid":[0-9]*' | head -1 | cut -d':' -f2)
[ -n "$TOTAL_PAID" ] && pass "total_paid present = $TOTAL_PAID" || fail "Missing total_paid"

UNPAID=$(echo "$RESPONSE" | grep -o '"total_unpaid":[0-9]*' | head -1 | cut -d':' -f2)
[ -n "$UNPAID" ] && pass "total_unpaid present = $UNPAID" || fail "Missing total_unpaid"

# ─────────────────────────────────────────────
section "Delete"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/bills/$BILL_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Bill deleted" || fail "Delete should return 200, got $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/bills/$BILL_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "404" ] && pass "Deleted bill returns 404" || fail "Should return 404, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(bills): recurring bills with cycle-aware payment tracking and budget summary\""
else
  echo -e "${RED}Fix failing tests before committing${NC}"
  exit 1
fi