# 測試指南

## 完整測試流程

### 1. 啟動服務

```bash
# 啟動所有服務（數據庫 + 應用）
make up

# 等待服務啟動（約 30-60 秒）
make logs

# 看到類似以下日誌表示啟動成功：
# Started SpringBootPrimaryReplicaDbApplication in X.XXX seconds
```

### 2. 測試讀寫分離（完整測試）

```bash
# 運行完整測試腳本
make test-rw

# 或直接運行
./test-rw-splitting.sh
```

**測試腳本會執行：**
1. ✅ 服務健康檢查
2. ✅ 數據庫連接信息
3. ✅ 寫操作測試（應該連接 Primary）
4. ✅ 讀操作測試（應該連接 Replica）
5. ✅ 負載均衡測試（10次讀取）
6. ✅ 數據一致性檢查

### 3. 查看實時日誌（推薦）

在一個終端運行：
```bash
make watch-logs
```

在另一個終端執行測試：
```bash
curl http://localhost:8080/api/users
```

**日誌輸出示例：**
```
📖 AOP 檢測到讀操作: UserService.getAllUsers(..)
🟢 路由決策: READ → SLAVE1 (Port: 5433)
```

## 手動測試步驟

### 測試 1：寫操作（Primary）

```bash
# 創建用戶
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

**預期結果：**
- 日誌顯示：`🔵 路由決策: WRITE → Primary Database (MASTER:5432)`
- 返回創建的用戶信息

### 測試 2：讀操作（Replica）

```bash
# 讀取所有用戶
curl http://localhost:8080/api/users
```

**預期結果：**
- 日誌顯示：`🟢 路由決策: READ → SLAVE1 (Port: 5433)` 或 `SLAVE2 (Port: 5434)`
- 返回所有用戶列表

### 測試 3：負載均衡

```bash
# 連續讀取10次
for i in {1..10}; do 
  echo "=== Read #$i ==="
  curl -s http://localhost:8080/api/users | jq '. | length'
done
```

**預期結果：**
- 日誌會顯示隨機切換在 Replica1 和 Replica2 之間
- 隨機性：約 50% SLAVE1，50% SLAVE2

### 測試 4：更新操作（Primary）

```bash
# 更新用戶（注意：替換 {id} 為實際用戶 ID）
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_updated",
    "email": "john.updated@example.com",
    "firstName": "John",
    "lastName": "Smith"
  }'
```

**預期結果：**
- 日誌顯示：`🔵 路由決策: WRITE → Primary Database (MASTER:5432)`

### 測試 5：數據庫驗證

```bash
# 在 Primary 查看數據
make shell-db-primary
SELECT COUNT(*) FROM users;
SELECT * FROM users;

# 在 Replica1 查看數據
make shell-db-replica1
SELECT COUNT(*) FROM users;

# 在 Replica2 查看數據
make shell-db-replica2
SELECT COUNT(*) FROM users;
```

## 驗證要點

### ✅ 寫操作驗證

1. **日誌顯示**：`🔵 路由決策: WRITE → Primary Database (MASTER:5432)`
2. **數據庫**：Primary 應該有新數據
3. **狀態碼**：HTTP 201 (創建) 或 200 (更新)

### ✅ 讀操作驗證

1. **日誌顯示**：`🟢 路由決策: READ → SLAVE1` 或 `SLAVE2`
2. **負載均衡**：多次讀取應在兩個 Replica 間隨機
3. **狀態碼**：HTTP 200

### ✅ AOP 驗證

1. **日誌顯示**：`📝 AOP 檢測到寫操作` 或 `📖 AOP 檢測到讀操作`
2. **方法名**：顯示正在執行的方法

## 常見問題排查

### 問題 1：日誌沒有顯示路由信息

**解決方案：**
```bash
# 確保日誌級別正確
# 檢查 application.yml 中的 logging.level

# 重新構建
make rebuild
```

### 問題 2：總是連接到 Primary

**檢查：**
1. `@Transactional(readOnly = true)` 是否正確設置
2. AOP 是否正常工作
3. DataSourceAspect 是否被 Spring 掃描

### 問題 3：無法連接 Replica

**解決方案：**
```bash
# 檢查 Replica 容器狀態
docker ps | grep replica

# 檢查 Replica 日誌
docker logs postgres-replica1
docker logs postgres-replica2
```

## 完整測試檢查清單

- [ ] 服務啟動成功
- [ ] 健康檢查通過
- [ ] 寫操作連接到 Primary
- [ ] 讀操作連接到 Replica
- [ ] 讀操作在兩個 Replica 間負載均衡
- [ ] 日誌顯示正確的路由決策
- [ ] AOP 正確攔截事務方法
- [ ] 數據能夠正確創建和讀取

## 測試報告模板

```
測試日期: YYYY-MM-DD
測試人員: Your Name

✅ 寫操作測試
- POST /api/users: 成功
- PUT /api/users/{id}: 成功
- 路由: Primary (5432)

✅ 讀操作測試
- GET /api/users: 成功
- GET /api/users/{id}: 成功
- 路由: Replica1 (5433) 或 Replica2 (5434)

✅ 負載均衡測試
- 10次讀取測試: 成功
- SLAVE1 使用次數: X
- SLAVE2 使用次數: 10-X

✅ 功能測試
- 用戶創建: 成功
- 用戶查詢: 成功
- 用戶更新: 成功
- 用戶刪除: 成功

結論: 讀寫分離正常工作
```

## 測試腳本使用說明

### test-rw-splitting.sh

完整測試腳本，包含所有測試場景。

**使用方式：**
```bash
./test-rw-splitting.sh
```

**功能：**
- 自動檢測服務狀態
- 執行所有讀寫測試
- 驗證負載均衡
- 檢查數據一致性
- 清理測試數據（可選）

### test-api.sh

基礎 API 測試腳本。

**使用方式：**
```bash
./test-api.sh
```

## 持續監控

### 實時監控讀寫分離

```bash
# 終端 1：監控日誌
make watch-logs

# 終端 2：執行測試
for i in {1..100}; do
  curl -s http://localhost:8080/api/users > /dev/null
  sleep 0.1
done
```

### 統計路由分布

```bash
# 收集 100 次讀取的日誌
make watch-logs 2>&1 | grep "路由決策" | tee routing.log

# 統計 Primary vs Replica 使用次數
cat routing.log | grep -c "Primary"
cat routing.log | grep -c "SLAVE"
```

## 進階測試

### 測試並發讀寫

```bash
# 同時執行多個讀寫操作
seq 1 10 | xargs -n1 -P10 -I{} sh -c '
  curl -X POST http://localhost:8080/api/users \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"user_{}\",\"email\":\"user{}@test.com\",\"firstName\":\"User\",\"lastName\":\"{}\"}"
'
```

### 壓力測試

```bash
# 使用 apache bench 測試
ab -n 1000 -c 10 http://localhost:8080/api/users
```

## 總結

按照上述步驟進行測試，可以確保：
1. ✅ 讀寫分離正確工作
2. ✅ 負載均衡正常
3. ✅ AOP 正確攔截
4. ✅ 數據一致性

如果所有測試通過，說明讀寫分離功能正常運作！

