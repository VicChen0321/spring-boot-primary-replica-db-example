#!/bin/bash

echo "=== 測試 Spring Boot Primary-Replica Database Demo ==="
echo ""

# 檢查服務是否運行
echo "1. 檢查服務狀態..."
if ! curl -s http://localhost:8080/api/health/db > /dev/null; then
    echo "❌ 服務未運行！請先執行 'make up' 或 'docker-compose up -d'"
    exit 1
fi
echo "✅ 服務正在運行"
echo ""

# 測試健康檢查
echo "2. 測試健康檢查端點..."
curl -s http://localhost:8080/api/health/db | jq .
echo ""

# 創建用戶（寫操作）
echo "3. 創建用戶（寫操作 → Primary）..."
CREATE_RESPONSE=$(curl -s -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "firstName": "John",
    "lastName": "Doe"
  }')

echo "$CREATE_RESPONSE" | jq .
USER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
echo "創建的用戶 ID: $USER_ID"
echo ""

# 讀取用戶（讀操作）
echo "4. 讀取所有用戶（讀操作 → Replica）..."
curl -s http://localhost:8080/api/users | jq .
echo ""

# 讀取特定用戶
echo "5. 讀取用戶 ID=$USER_ID（讀操作 → Replica）..."
curl -s http://localhost:8080/api/users/$USER_ID | jq .
echo ""

# 搜索用戶
echo "6. 搜索用戶（讀操作 → Replica）..."
curl -s "http://localhost:8080/api/users/search?name=John" | jq .
echo ""

# 更新用戶（寫操作）
echo "7. 更新用戶（寫操作 → Primary）..."
curl -s -X PUT http://localhost:8080/api/users/$USER_ID \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_updated",
    "email": "john.updated@example.com",
    "firstName": "John",
    "lastName": "Smith"
  }' | jq .
echo ""

# 驗證更新
echo "8. 驗證更新後的用戶..."
curl -s http://localhost:8080/api/users/$USER_ID | jq .
echo ""

echo "=== 測試完成 ==="

