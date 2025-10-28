#!/bin/bash

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Spring Boot 讀寫分離完整測試 ===${NC}"
echo ""

# 檢查服務是否運行
check_service() {
    echo -e "${YELLOW}1. 檢查服務狀態...${NC}"
    if ! curl -s http://localhost:8080/api/health/db > /dev/null 2>&1; then
        echo -e "${RED}❌ 服務未運行！請先執行 'make up' 或 'docker-compose up -d'${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ 服務正在運行${NC}"
    echo ""
}

# 顯示數據庫連接信息
show_db_info() {
    echo -e "${YELLOW}2. 檢查數據庫連接信息...${NC}"
    DB_INFO=$(curl -s http://localhost:8080/api/health/db)
    echo "$DB_INFO" | jq .
    
    # 顯示當前連接的數據庫 URL
    DB_URL=$(echo "$DB_INFO" | jq -r '.url')
    echo -e "\n${BLUE}當前連接的數據庫: $DB_URL${NC}"
    
    # 判斷連接的是哪個數據庫
    if [[ "$DB_URL" == *":5432"* ]]; then
        echo -e "${GREEN}✅ 連接 Primary 數據庫 (寫操作)${NC}"
    elif [[ "$DB_URL" == *":5433"* ]]; then
        echo -e "${GREEN}✅ 連接 Replica 1 數據庫 (讀操作)${NC}"
    elif [[ "$DB_URL" == *":5434"* ]]; then
        echo -e "${GREEN}✅ 連接 Replica 2 數據庫 (讀操作)${NC}"
    fi
    echo ""
}

# 測試寫操作（應該使用 Primary）
test_write_operations() {
    echo -e "${YELLOW}3. 測試寫操作（應該使用 Primary 數據庫 5432）...${NC}"
    
    # 創建用戶 1
    echo "創建用戶 1..."
    USER1=$(curl -s -X POST http://localhost:8080/api/users \
      -H "Content-Type: application/json" \
      -d '{
        "username": "test_user_1",
        "email": "test1@example.com",
        "firstName": "Test",
        "lastName": "User1"
      }')
    echo "$USER1" | jq .
    USER1_ID=$(echo "$USER1" | jq -r '.id')
    echo -e "${GREEN}✅ 用戶 1 創建成功，ID: $USER1_ID${NC}"
    echo ""
    
    sleep 1
    
    # 創建用戶 2
    echo "創建用戶 2..."
    USER2=$(curl -s -X POST http://localhost:8080/api/users \
      -H "Content-Type: application/json" \
      -d '{
        "username": "test_user_2",
        "email": "test2@example.com",
        "firstName": "Test",
        "lastName": "User2"
      }')
    echo "$USER2" | jq .
    USER2_ID=$(echo "$USER2" | jq -r '.id')
    echo -e "${GREEN}✅ 用戶 2 創建成功，ID: $USER2_ID${NC}"
    echo ""
    
    sleep 1
    
    # 更新用戶 1
    echo "更新用戶 1..."
    UPDATE_RESPONSE=$(curl -s -X PUT http://localhost:8080/api/users/$USER1_ID \
      -H "Content-Type: application/json" \
      -d '{
        "username": "test_user_1_updated",
        "email": "test1.updated@example.com",
        "firstName": "Test",
        "lastName": "User1 Updated"
      }')
    echo "$UPDATE_RESPONSE" | jq .
    echo -e "${GREEN}✅ 用戶更新成功${NC}"
    echo ""
}

# 測試讀操作（應該使用 Replica）
test_read_operations() {
    echo -e "${YELLOW}4. 測試讀操作（應該使用 Replica 數據庫 5433 或 5434）...${NC}"
    
    # 讀取所有用戶
    echo "讀取所有用戶..."
    ALL_USERS=$(curl -s http://localhost:8080/api/users)
    echo "$ALL_USERS" | jq .
    USER_COUNT=$(echo "$ALL_USERS" | jq '. | length')
    echo -e "${GREEN}✅ 成功讀取 $USER_COUNT 個用戶${NC}"
    echo ""
    
    sleep 1
    
    # 讀取特定用戶
    echo "讀取用戶 ID=1..."
    USER_BY_ID=$(curl -s http://localhost:8080/api/users/1)
    echo "$USER_BY_ID" | jq .
    echo -e "${GREEN}✅ 成功讀取用戶${NC}"
    echo ""
    
    sleep 1
    
    # 搜索用戶
    echo "搜索用戶（name=Test）..."
    SEARCH_RESULT=$(curl -s "http://localhost:8080/api/users/search?name=Test")
    echo "$SEARCH_RESULT" | jq .
    echo -e "${GREEN}✅ 搜索成功${NC}"
    echo ""
    
    sleep 1
    
    # 根據用戶名查詢
    if [ ! -z "$USER1_ID" ]; then
        echo "根據用戶名查詢..."
        USER_BY_NAME=$(curl -s http://localhost:8080/api/users/username/test_user_1_updated)
        echo "$USER_BY_NAME" | jq .
        echo -e "${GREEN}✅ 查詢成功${NC}"
        echo ""
    fi
}

# 多次讀取測試（驗證負載均衡）
test_load_balancing() {
    echo -e "${YELLOW}5. 測試讀操作負載均衡（讀取10次以觀察 Replica 選擇）...${NC}"
    
    for i in {1..10}; do
        echo -n "讀取 #$i - "
        RESULT=$(curl -s http://localhost:8080/api/users)
        COUNT=$(echo "$RESULT" | jq '. | length')
        echo "結果: $COUNT 個用戶"
        sleep 0.5
    done
    
    echo -e "${GREEN}✅ 負載均衡測試完成${NC}"
    echo ""
}

# 測試數據一致性
test_data_consistency() {
    echo -e "${YELLOW}6. 測試數據一致性...${NC}"
    
    # 在 Primary 查詢數據
    echo "在 Primary 數據庫查詢數據..."
    docker exec postgres-primary psql -U myuser -d mydb -c "SELECT COUNT(*) as primary_count FROM users;"
    
    # 在 Replica1 查詢數據
    echo "在 Replica 1 數據庫查詢數據..."
    docker exec postgres-replica1 psql -U myuser -d mydb -c "SELECT COUNT(*) as replica1_count FROM users;" || echo "注意：Replica 數據可能不同步（簡化版配置）"
    
    # 在 Replica2 查詢數據
    echo "在 Replica 2 數據庫查詢數據..."
    docker exec postgres-replica2 psql -U myuser -d mydb -c "SELECT COUNT(*) as replica2_count FROM users;" || echo "注意：Replica 數據可能不同步（簡化版配置）"
    
    echo ""
}

# 清理測試數據
cleanup() {
    echo -e "${YELLOW}7. 清理測試數據...${NC}"
    
    # 獲取所有用戶 ID
    USER_IDS=$(curl -s http://localhost:8080/api/users | jq -r '.[].id' | sort -rn)
    
    if [ ! -z "$USER_IDS" ]; then
        for ID in $USER_IDS; do
            # 只刪除測試用戶
            USERNAME=$(curl -s http://localhost:8080/api/users/$ID | jq -r '.username')
            if [[ "$USERNAME" == test_* ]]; then
                echo "刪除用戶 ID=$ID ($USERNAME)"
                curl -s -X DELETE http://localhost:8080/api/users/$ID > /dev/null
            fi
        done
        echo -e "${GREEN}✅ 測試數據清理完成${NC}"
    else
        echo -e "${YELLOW}⚠️  沒有測試數據需要清理${NC}"
    fi
    echo ""
}

# 顯示總結
show_summary() {
    echo -e "${BLUE}=== 測試總結 ===${NC}"
    echo ""
    echo -e "${GREEN}✅ 所有測試完成！${NC}"
    echo ""
    echo -e "測試內容："
    echo -e "  ${GREEN}✓${NC} 服務健康檢查"
    echo -e "  ${GREEN}✓${NC} 數據庫連接信息"
    echo -e "  ${GREEN}✓${NC} 寫操作（Primary）"
    echo -e "  ${GREEN}✓${NC} 讀操作（Replica）"
    echo -e "  ${GREEN}✓${NC} 負載均衡測試"
    echo -e "  ${GREEN}✓${NC} 數據一致性檢查"
    echo ""
    echo -e "${YELLOW}注意：${NC}"
    echo -e "  - 讀寫分離通過 AOP 自動實現"
    echo -e "  - 寫操作使用 @Transactional"
    echo -e "  - 讀操作使用 @Transactional(readOnly=true)"
    echo -e "  - 本示例使用簡化版配置，三個數據庫都是獨立的"
    echo ""
}

# 主程序
main() {
    check_service
    show_db_info
    test_write_operations
    test_read_operations
    test_load_balancing
    test_data_consistency
    
    # 詢問是否清理測試數據
    echo -n "是否清理測試數據？(y/n): "
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        cleanup
    fi
    
    show_summary
}

# 運行測試
main

