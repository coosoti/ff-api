#!/bin/bash

# ─────────────────────────────────────────────
# Module 1 — Auth API Test Script
# Usage: chmod +x test-auth.sh && ./test-auth.sh
# Make sure the API is running: npm run dev
# ─────────────────────────────────────────────

BASE_URL="http://localhost:5001/api/v1"
EMAIL="test_$(date +%s)@example.com"
PASSWORD="Test@1234"
ACCESS_TOKEN=""
REFRESH_TOKEN=""
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; ((PASS++)); }
fail() { echo -e "${RED}✗ $1${NC}"; ((FAIL++)); }
section() { echo -e "\n${YELLOW}── $1 ──${NC}"; sleep 0.5; }

# Helper — extract a JSON field value
json_val() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | cut -d'"' -f4; }

# ─────────────────────────────────────────────
section "Health check"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/health)
if [ "$STATUS" = "200" ]; then
  pass "Server is running"
else
  fail "Server is not running (got $STATUS) — run: npm run dev"
  exit 1
fi

# ─────────────────────────────────────────────
section "US-001 — Register"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Test User\",\"monthly_income\":100000,\"dependents\":0}")

ACCESS_TOKEN=$(json_val "$RESPONSE" "accessToken")
REFRESH_TOKEN=$(json_val "$RESPONSE" "refreshToken")

if [ -n "$ACCESS_TOKEN" ]; then
  pass "Register returns accessToken"
else
  fail "Register failed: $RESPONSE"
fi

if [ -n "$REFRESH_TOKEN" ]; then
  pass "Register returns refreshToken"
else
  fail "Register missing refreshToken"
fi

# Duplicate email
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Dupe\",\"monthly_income\":50000}")
[ "$STATUS" = "400" ] && pass "Duplicate email rejected (400)" || fail "Duplicate email should return 400, got $STATUS"

# Invalid fields
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"bad","password":"short"}')
[ "$STATUS" = "400" ] && pass "Invalid fields rejected (400)" || fail "Invalid fields should return 400, got $STATUS"

# ─────────────────────────────────────────────
section "US-002 — Login"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

NEW_ACCESS=$(json_val "$RESPONSE" "accessToken")
NEW_REFRESH=$(json_val "$RESPONSE" "refreshToken")

if [ -n "$NEW_ACCESS" ]; then
  ACCESS_TOKEN=$NEW_ACCESS
  REFRESH_TOKEN=$NEW_REFRESH
  pass "Login returns accessToken"
else
  fail "Login failed: $RESPONSE"
fi

# Wrong password
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"WrongPass@99\"}")
[ "$STATUS" = "401" ] && pass "Wrong password rejected (401)" || fail "Wrong password should return 401, got $STATUS"

# ─────────────────────────────────────────────
section "US-003 — Refresh token"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X POST "$BASE_URL/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_TOKEN\"}")

NEW_ACCESS=$(json_val "$RESPONSE" "accessToken")
if [ -n "$NEW_ACCESS" ]; then
  ACCESS_TOKEN=$NEW_ACCESS
  pass "Refresh returns new accessToken"
else
  fail "Refresh failed — token used: $REFRESH_TOKEN — response: $RESPONSE"
fi

# Invalid token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"bad.token.here"}')
[ "$STATUS" = "401" ] && pass "Invalid refresh token rejected (401)" || fail "Invalid refresh token should return 401, got $STATUS"

# ─────────────────────────────────────────────
section "US-004 — Forgot password"
# ─────────────────────────────────────────────

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/forgot-password" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\"}")
[ "$STATUS" = "200" ] && pass "Forgot password 200 for known email" || fail "Forgot password should return 200, got $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{"email":"nobody@nowhere.com"}')
[ "$STATUS" = "200" ] && pass "Forgot password 200 for unknown email (no enumeration)" || fail "Should always return 200, got $STATUS"

# ─────────────────────────────────────────────
section "GET /auth/me"
# ─────────────────────────────────────────────

RESPONSE=$(curl -s -X GET "$BASE_URL/auth/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

USER_EMAIL=$(json_val "$RESPONSE" "email")
[ "$USER_EMAIL" = "$EMAIL" ] && pass "GET /me returns correct user" || fail "GET /me failed: $RESPONSE"

# No token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/auth/me")
[ "$STATUS" = "401" ] && pass "GET /me without token rejected (401)" || fail "Should return 401, got $STATUS"

# ─────────────────────────────────────────────
echo -e "\n─────────────────────────────────"
echo -e "${GREEN}PASSED: $PASS${NC} | ${RED}FAILED: $FAIL${NC}"
echo "─────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All tests passed — ready to commit${NC}"
  echo ""
  echo "  git add ."
  echo "  git commit -m \"feat(auth): US-001 to US-004 — register, login, refresh, forgot-password\""
else
  echo -e "${RED}Fix the failing tests before committing${NC}"
  exit 1
fi