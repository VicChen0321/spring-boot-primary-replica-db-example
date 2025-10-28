# 快速開始

## 一分鐘啟動

```bash
# 1. 啟動所有服務
make up

# 2. 等待服務啟動（約 30-60 秒）
# 查看啟動日誌
make logs

# 3. 測試 API
# 創建用戶
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","firstName":"Test","lastName":"User"}'

# 讀取用戶
curl http://localhost:8080/api/users

# 健康檢查
curl http://localhost:8080/api/health/db
```

## 使用測試腳本

```bash
# 啟動服務後，運行測試腳本
./test-api.sh
```

## 常用命令

### 服務管理

```bash
make up          # 啟動所有服務
make down        # 停止服務
make logs        # 查看應用日誌
make logs-all    # 查看所有服務日誌
make status      # 查看服務狀態
make clean       # 完全清理（刪除數據）
make rebuild     # 重新構建並啟動
```

### 數據庫訪問

```bash
make shell-db-primary   # 進入 Primary 數據庫
make shell-db-replica1  # 進入 Replica 1 數據庫
make shell-db-replica2  # 進入 Replica 2 數據庫
```

### 應用訪問

```bash
make shell-app  # 進入應用容器
```

### 本地開發

```bash
# 只啟動數據庫
docker-compose up -d postgres-primary postgres-replica1 postgres-replica2

# 本地構建和運行
make build-local
make run-local
```

## 驗證讀寫分離

### 方法 1: 查看日誌

```bash
# 查看應用日誌，會顯示 SQL 操作
make logs
```

### 方法 2: 直接查詢數據庫

```bash
# 在 Primary 創建數據
make shell-db-primary
INSERT INTO users (username, email, first_name, last_name, created_at, updated_at)
VALUES ('test', 'test@example.com', 'Test', 'User', NOW(), NOW());

# 在 Replica 1 和 Replica 2 查詢
make shell-db-replica1
SELECT * FROM users;

make shell-db-replica2
SELECT * FROM users;
```

注意：本示例使用的是三個獨立的數據庫（簡化版）。在生產環境中，應使用真正的 replication。

## 常用 API

### 用戶管理

```bash
# 創建用戶
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice",
    "email": "alice@example.com",
    "firstName": "Alice",
    "lastName": "Smith"
  }'

# 獲取所有用戶
curl http://localhost:8080/api/users

# 獲取特定用戶
curl http://localhost:8080/api/users/1

# 搜索用戶
curl "http://localhost:8080/api/users/search?name=Alice"

# 更新用戶
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_updated",
    "email": "alice.updated@example.com",
    "firstName": "Alice",
    "lastName": "Johnson"
  }'

# 刪除用戶
curl -X DELETE http://localhost:8080/api/users/1
```

## 健康檢查

```bash
# 檢查數據庫連接
curl http://localhost:8080/api/health/db

# Spring Boot Actuator
curl http://localhost:8080/actuator/health
```

## 故障排除

### 服務無法啟動

```bash
# 檢查端口是否被佔用
lsof -i :8080
lsof -i :5432
lsof -i :5433
lsof -i :5434

# 檢查服務狀態
docker-compose ps

# 查看詳細日誌
docker-compose logs
```

### 數據庫連接失敗

```bash
# 檢查數據庫容器狀態
docker ps | grep postgres

# 嘗試手動連接
docker exec -it postgres-primary psql -U myuser -d mydb
```

### 清理重新開始

```bash
# 完全清理
make clean

# 重新啟動
make up
```

## 下一步

- 查看 [README.md](README.md) 了解完整文檔
- 查看 [ARCHITECTURE.md](ARCHITECTURE.md) 了解系統架構
- 查看 [HELP.md](HELP.md) 了解詳細使用說明
- 查看源代碼了解實現細節

## 技術支援

遇到問題？
1. 查看日誌：`make logs`
2. 檢查服務狀態：`make status`
3. 查看幫助文檔：`HELP.md`
4. 重新啟動：`make rebuild`

