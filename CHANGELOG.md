# 更新日誌

## 2024 - 使用 Lombok 建構子注入 + 讀寫分離完整測試

### 主要變更

#### 1. 依賴注入方式改進

**變更前：使用 @Autowired 字段注入**
```java
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;
}
```

**變更後：使用 Lombok @RequiredArgsConstructor 建構子注入**
```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
}
```

**優勢：**
- ✅ **不可變性**：使用 `final` 修飾符，保證不可變
- ✅ **線程安全**：沒有 setter 注入的風險
- ✅ **易於測試**：建構子注入更容易進行單元測試
- ✅ **符合 Spring 最佳實踐**：Spring 推薦建構子注入
- ✅ **代碼更簡潔**：Lombok 自動生成建構子

#### 2. 修改的文件

以下文件已經更新為建構子注入：
- `UserService.java` - 服務層
- `UserController.java` - 控制器層
- `HealthController.java` - 健康檢查控制器

#### 3. 讀寫分離日誌增強

**DataSourceConfig.java**
- 添加了路由決策日誌
- 可以清楚看到每次操作使用的數據庫

**DataSourceAspect.java**
- 添加了 AOP 攔截日誌
- 可以追蹤讀寫操作的分類

**日誌輸出示例：**
```
📝 AOP 檢測到寫操作: UserService.createUser(..)
🔵 路由決策: WRITE → Primary Database (MASTER:5432)

📖 AOP 檢測到讀操作: UserService.getAllUsers(..)
🟢 路由決策: READ → SLAVE1 (Port: 5433)
```

#### 4. 完整測試腳本

創建了 `test-rw-splitting.sh` 腳本，用於：
- 測試寫操作（連接 Primary）
- 測試讀操作（連接 Replica）
- 驗證負載均衡
- 檢查數據一致性

### 如何測試

#### 方法 1：使用測試腳本（推薦）

```bash
# 啟動服務
make up

# 等待服務完全啟動後
./test-rw-splitting.sh
```

#### 方法 2：手動測試

```bash
# 1. 查看實時日誌（可以看到路由決策）
make logs

# 2. 在另一個終端執行測試

# 寫操作（應該顯示連接 Primary）
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","firstName":"Test","lastName":"User"}'

# 讀操作（應該顯示連接 Replica 1 或 Replica 2）
curl http://localhost:8080/api/users
```

### 驗證讀寫分離

#### 1. 查看日誌輸出

運行測試時，日誌會顯示：
- 🔵 **寫操作** - 顯示連接 Primary (5432)
- 🟢 **讀操作** - 顯示連接 Replica (5433 或 5434)

#### 2. 多次讀取測試

```bash
# 連續讀取10次，觀察 Replica 的切換
for i in {1..10}; do curl -s http://localhost:8080/api/users | jq '. | length'; done
```

每次讀取應該隨機選擇 Replica 1 或 Replica 2。

#### 3. 檢查數據庫

```bash
# Primary 數據庫
make shell-db-primary
SELECT * FROM users;

# Replica 1
make shell-db-replica1  
SELECT * FROM users;

# Replica 2
make shell-db-replica2
SELECT * FROM users;
```

### 技術改進總結

| 項目 | 改進前 | 改進後 | 優勢 |
|------|--------|--------|------|
| 依賴注入 | @Autowired 字段注入 | @RequiredArgsConstructor 建構子注入 | 不可變、線程安全、易測試 |
| 日誌追蹤 | 無 | 完整的路由決策日誌 | 易於調試和驗證 |
| 測試覆蓋 | 基礎測試 | 完整測試腳本 | 涵蓋所有場景 |

### 注意事項

1. **簡化版配置**：當前三個數據庫都是獨立的（非真正 replication）
2. **測試目的**：演示讀寫分離的路由邏輯
3. **生產環境**：需要配置真正的 PostgreSQL replication

### 下一步

如果需要更多功能：
- [ ] 添加 Replica 健康檢查
- [ ] 實現故障自動切換
- [ ] 添加連接池監控
- [ ] 實現真正的 PostgreSQL replication

