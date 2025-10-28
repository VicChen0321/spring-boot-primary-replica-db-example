# Spring Boot Primary-Replica Database Example

這是一個使用 Spring Boot 實現 PostgreSQL 讀寫分離的完整範例專案。專案配置了 1 個 Primary 數據庫和 2 個 Replica 數據庫，實現了自動的讀寫路由。

## 技術棧

- **Java 21**
- **Spring Boot 3.5.7**
- **PostgreSQL** (最新版本)
- **Gradle KTS**
- **Docker & Docker Compose**
- **HikariCP** (連接池)
- **Lombok** (建構子注入)

## 專案結構

```
spring-boot-primary-replica-db-example/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/example/dbexample/
│   │   │       ├── config/          # 數據源配置（讀寫分離核心）
│   │   │       ├── controller/      # REST API
│   │   │       ├── model/           # 實體類
│   │   │       ├── repository/      # 數據訪問層
│   │   │       └── service/         # 業務邏輯層
│   │   └── resources/
│   │       └── application.yml      # 應用配置
├── init-scripts/                     # PostgreSQL 初始化腳本
├── build.gradle.kts                  # Gradle 配置
├── Dockerfile                        # Docker 構建文件
├── docker-compose.yml                # Docker Compose 配置
└── 測試腳本/
    ├── test-api.sh                  # 基礎 API 測試
    └── test-rw-splitting.sh         # 讀寫分離完整測試
```

## 快速開始

### 使用 Makefile（推薦）

```bash
# 1. 啟動所有服務
make up

# 2. 查看日誌
make logs

# 3. 運行完整測試
make test-rw
```

### 手動啟動

```bash
# 1. 啟動服務
docker-compose up -d

# 2. 查看日誌
docker-compose logs -f app

# 3. 測試 API
curl http://localhost:8080/api/users
```

## 讀寫分離機制

### 工作原理

1. **寫操作** (`@Transactional` 或 `@Transactional(readOnly = false)`):
   - 路由到 Primary 數據庫 (端口 5432)
   - 日誌顯示：`🔵 路由決策: WRITE → Primary Database`

2. **讀操作** (`@Transactional(readOnly = true)`):
   - 隨機路由到其中一個 Replica 數據庫 (端口 5433 或 5434)
   - 日誌顯示：`🟢 路由決策: READ → SLAVE1/SLAVE2`
   - 實現負載均衡

### 核心組件

- **DataSourceConfig**: 配置多個數據源和路由邏輯
- **ReplicationRoutingDataSource**: 自定義路由數據源
- **ReplicationContextHolder**: 線程本地變量，存儲當前操作類型
- **DataSourceAspect**: AOP 切面，根據 `@Transactional` 注解自動設置讀寫類型

## 技術亮點

### 1. 建構子注入（推薦方式）

使用 Lombok `@RequiredArgsConstructor` 實現建構子注入：

```java
@Service
@RequiredArgsConstructor
public class UserServiceExecutor {
    private final UserRepository userRepository;  // final 修飾符，不可變
}
```

**優勢：**
- ✅ 不可變性：`final` 修飾符
- ✅ 線程安全
- ✅ 易於測試
- ✅ 符合 Spring 最佳實踐

### 2. 實時路由追蹤

每次數據庫操作都會輸出詳細日誌：

```
📝 AOP 檢測到寫操作: UserService.createUser(..)
相关系數決策: WRITE → Primary Database (MASTER:5432)

📖 AOP 檢測到讀操作: UserService.getAllUsers(..)
🟢 路由決策: READ → SLAVE1 (Port: 5433)
```

### 3. 自動負載均衡

讀操作自動在兩個 Replica 之間隨機分發，無需額外配置。

## API 端點

### 用戶管理 API

- `POST /api/users` - 創建用戶 (寫操作 → Primary)
- `GET /api/users` - 獲取所有用戶 (讀操作 → Replica)
- `GET /api/users/{id}` - 根據 ID 獲取用戶 (讀操作 → Replica)
- `GET /api/users/username/{username}` - 根據用戶名獲取用戶 (讀操作 → Replica)
- `GET /api/users/search?name={name}` - 搜索用戶 (讀操作 → Replica)
- `PUT /api/users/{id}` - 更新用戶 (寫操作 → Primary)
- `DELETE /api/users/{id}` - 刪除用戶 (寫操作 → Primary)

### 健康檢查 API

- `GET /api/health/db` - 檢查數據庫連接狀態

## 完整測試

### 自動測試

```bash
# 運行完整測試腳本
make test-rw

# 或
./test-rw-splitting.sh
```

**測試內容：**
1. ✅ 服務健康檢查
2. ✅ 寫操作測試
3. ✅ 讀操作測試
4. ✅ 負載均衡驗證
5. ✅ 數據一致性檢查

### 手動測試

```bash
# 實時查看路由決策日誌
make watch-logs

# 在另一個終端執行測試
curl http://localhost:8080/api/users
```

詳細測試指南請參考 [TESTING.md](TESTING.md)

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

### 測試命令

```bash
make test-rw     # 測試讀寫分離
make test-api    # 測試 API
make watch-logs  # 實時查看路由決策日誌
```

### 數據庫訪問

```bash
make shell-db-primary   # 進入 Primary 數據庫
make shell-db-replica1  # 進入 Replica 1 數據庫
make shell-db-replica2  # 進入 Replica 2 數據庫
make shell-app          # 進入應用容器
```

## 文檔索引

- [README.md](README.md) - 項目總覽（本文件）
- [QUICKSTART.md](QUICKSTART.md) - 快速開始指南
- [TESTING.md](TESTING.md) - 詳細測試指南
- [ARCHITECTURE.md](ARCHITECTURE.md) - 系統架構說明
- [CHANGELOG.md](CHANGELOG.md) - 更新日誌
- [READ-WRITE-SPLITTING-COMPARISON.md](READ-WRITE-SPLITTING-COMPARISON.md) - 讀寫分離方案對比
- [HELP.md](HELP.md) - 使用幫助

## 注意事項

### 簡化版配置

本示例使用了**簡化的配置**，三個數據庫都是獨立的實例，並未實現真正的 PostgreSQL replication。

**為什麼簡化？**
- 更容易啟動和測試
- 重點演示讀寫分離的路由邏輯
- 避免複雜的 replication 配置

### 生產環境

在生產環境中，你需要：
1. 配置真正的 PostgreSQL replication
2. 實現 Replica 健康檢查
3. 添加故障自動切換
4. 配置監控和告警

## 測試範例

### 創建用戶（寫操作）

```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

### 讀取用戶（讀操作）

```bash
# 獲取所有用戶
curl http://localhost:8080/api/users

# 根據 ID 獲取
curl http://localhost:8080/api/users/1

# 搜索用戶
curl "http://localhost:8080/api/users/search?name=John"
```

### 檢查數據庫連接

```bash
curl http://localhost:8080/api/health/db
```

## 監控和日誌

### 查看讀寫路由

應用日誌會顯示所有數據庫操作和路由決策。使用以下命令實時查看：

```bash
make watch-logs
```

### 檢查數據庫狀態

```bash
# 檢查 Primary
docker exec -it postgres-primary psql -U myuser -d mydb -c "SELECT * FROM users;"

# 檢查 Replica 1
docker exec -it postgres-replica1 psql -U myuser -d mydb -c "SELECT * FROM users;"

# 檢查 Replica 2
docker exec -it postgres-replica2 psql -U myuser -d mydb -c "SELECT * FROM users;"
```

## 配置說明

### 數據源配置

在 `application.yml` 中配置了三個數據源：

- **primary**: 主數據庫，處理所有寫操作
- **replica1**: 第一個副本數據庫，處理讀操作
- **replica2**: 第二個副本數據庫，處理讀操作

每個數據源都配置了 HikariCP 連接池。

### 環境變量

在 Docker 環境中，可以通過環境變量覆蓋配置。詳見 `docker-compose.yml`。

## 故障排除

### 服務無法啟動

```bash
# 檢查端口是否被佔用
lsof -i :8080
lsof -i :5432

# 檢查服務狀態
make status

# 查看詳細日誌
docker-compose logs
```

### 數據庫連接失敗

```bash
# 檢查數據庫容器狀態
docker ps | grep postgres

# 檢查應用日誌
make logs
```

### 完全重新開始

```bash
make clean
make up
```

## 許可證

MIT

## 貢獻

歡迎提交 Issue 和 Pull Request！

## 更新記錄

詳細更新記錄請參考 [CHANGELOG.md](CHANGELOG.md)

### 最新更新

- ✅ 使用 Lombok `@RequiredArgsConstructor` 實現建構子注入
- ✅ 添加完整的路由決策日誌
- ✅ 新增完整測試腳本
- ✅ 增強日誌追蹤功能
