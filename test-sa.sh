RESPONSE=$(curl -s -X POST http://localhost:5001/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test_'$(date +%s)'@example.com","password":"Test@1234","name":"Test","monthly_income":100000,"dependents":0}')

echo "REGISTER: $RESPONSE" | head -c 200

TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
echo "TOKEN: ${TOKEN:0:20}..."

curl -s -X POST http://localhost:5001/api/v1/savings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Emergency Fund","target_amount":300000}'
