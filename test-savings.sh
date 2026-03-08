#!/bin/bash

# ─────────────────────────────────────────────
# Module 4 — Savings Goals API Test Script
# Usage: chmod +x test-savings.sh && ./test-savings.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="savings_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
GOAL_ID=""
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}✗ $1${NC}"; FAIL=$((FAIL+1)); }
section() { echo -e "\n${YELLOW}── $1 ──${NC}"; sleep 0.5; }
json_val() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
json_num() { echo "$1" | grep -o "\"$2\":[0-9.]*" | head -1 | cut -d':' -f2; }

# ─────────────────────────────────────────────
section "Setup — register"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Savings User\",\"monthly_income\":100000,\"dependents\":0}")

ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
[ -n "$ACCESS_TOKEN" ] && pass "Registered and got token" || { fail "Registration failed: $RESPONSE"; exit 1; }

# ─────────────────────────────────────────────
section "Create savings goals"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/savings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Emergency Fund","target_amount":300000,"current_amount":50000,"target_date":"2026-12-31","notes":"6 months expenses"}')
GOAL_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$GOAL_ID" ] && pass "Emergency Fund goal created" || { fail "Create failed: $RESPONSE"; exit 1; }

RESPONSE=$(curl -s -X POST "$BASE_URL/savings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Vacation","target_amount":80000,"current_amount":0}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Vacation goal created" || fail "Create failed: $RESPONSE"

# Invalid — negative target
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/savings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Bad","target_amount":-1000}')
[ "$STATUS" = "400" ] && pass "Negative target rejected (400)" || fail "Should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "Get savings goals"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s "$BASE_URL/savings" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
COUNT=$(echo "$RESPONSE" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 2 ] && pass "Got $COUNT goals" || fail "Expected 2+ goals, got $COUNT"

RESPONSE=$(curl -s "$BASE_URL/savings/$GOAL_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Get by id works" || fail "Get by id failed: $RESPONSE"

# ─────────────────────────────────────────────
section "Top up savings goal"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/savings/$GOAL_ID/topup" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"amount":25000}')
CURRENT=$(json_num "$RESPONSE" "current_amount")
[ "$CURRENT" = "75000" ] && pass "Top up: current_amount = 75000 (50000 + 25000)" || fail "Expected 75000, got $CURRENT"

IS_COMPLETED=$(echo "$RESPONSE" | grep -o '"is_completed":false')
[ -n "$IS_COMPLETED" ] && pass "Goal not yet completed" || fail "Should not be completed yet"

# Top up to completion
RESPONSE=$(curl -s -X POST "$BASE_URL/savings/$GOAL_ID/topup" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"amount":250000}')
IS_COMPLETED=$(echo "$RESPONSE" | grep -o '"is_completed":true')
[ -n "$IS_COMPLETED" ] && pass "Goal auto-completed when target reached" || fail "Should be completed: $RESPONSE"

# ─────────────────────────────────────────────
section "Update savings goal"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X PUT "$BASE_URL/savings/$GOAL_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"name":"Emergency Fund (Updated)","target_amount":350000}')
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
[ -n "$SUCCESS" ] && pass "Goal updated" || fail "Update failed: $RESPONSE"

# ─────────────────────────────────────────────
section "Delete savings goal"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/savings/$GOAL_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "200" ] && pass "Goal deleted" || fail "Delete should return 200, got $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/savings/$GOAL_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
[ "$STATUS" = "404" ] && pass "Deleted goal returns 404" || fail "Should return 404, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(savings): US — savings goals with top-up and auto-complete\""
else
  echo -e "${RED}Fix failing tests before committing${NC}"
  exit 1
fi