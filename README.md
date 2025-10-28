# Spring Boot Primary-Replica Database Example

這是一個使用 Spring Boot 實現 PostgreSQL 讀寫分離的完整範例專案。專案配置了 1 個 Primary 數據庫和 2 個 Replica 數據庫，實現了自動的讀寫路由。

## 技術棧

- **Java 21**
- **Spring Boot 3.5.7**
- **PostgreSQL** (最新版本)
- **Gradle KTS**
- **Docker & Docker Compose**
- **HikariCP** (連接池)

## 專案結構

```
spring-boot-primary-replica-db-example/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/example/dbexample/
│   │   │       ├── config/          # 數據源配置
│   │   │       ├── controller/      # REST API
│   │   │       ├── model/           # 實體類
│   │   │       ├── repository/      # 數據訪問層
│   │   │       └── service/         # 業務邏輯層
│   │   └── resources/
│   │       └── application.yml      # 應用配置
├── init-scripts/                     # PostgreSQL 初始化腳本
├── build.gradle.kts                  # Gradle 配置
├── Dockerfile                        # Docker 構建文件
└── docker-compose.yml                # Docker Compose 配置
```

## 讀寫分離實現

### 工作原理

1. **寫操作** (`@Transactional(readOnly = false)` 或無注解):
   - 路由到 Primary 數據庫 (端口 5432)

2. **讀操作** (`@Transactional(readOnly = true)`):
   - 隨機路由到其中一個 Replica 數據庫 (端口 5433 或 5434)
   - 實現負載均衡

### 核心組件

- `DataSourceConfig`: 配置多個數據源和路由邏輯
- `ReplicationRoutingDataSource`: 自定義路由數據源
- `ReplicationContextHolder`: 線程本地變量，存儲當前操作類型
- `DataSourceAspect`: AOP 切面，根據 `@Transactional` 注解自動設置讀寫類型

## 快速開始

### 前置要求

- Docker & Docker Compose
- Java 21+ (本地運行時需要)

### 使用 Docker 部署

1. **啟動所有服務**

```bash
docker-compose up -d
```

這會啟動：
- PostgreSQL Primary (端口 5432)
- PostgreSQL Replica 1 (端口 5433)
- PostgreSQL Replica 2 (端口 5434)
- Spring Boot 應用 (端口 8080)

2. **查看日誌**

```bash
# 查看所有服務日誌
docker-compose logs -f

# 查看特定服務日誌
docker-compose logs -f app
docker-compose logs -f postgres-primary
```

3. **停止服務**

```bash
docker-compose down

# 同時刪除數據卷
docker-compose down -v
```

### 本地開發

1. **確保 PostgreSQL 正在運行** (使用 Docker Compose 只啟動數據庫)

```bash
docker-compose up -d postgres-primary postgres-replica1 postgres-replica2
```

2. **編譯和運行**

```bash
./gradlew clean build
./gradlew bootRun
```

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

## 測試範例

### 創建用戶 (寫操作)

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

### 讀取用戶 (讀操作)

```bash
# 獲取所有用戶
curl http://localhost:8080/api/users

# 根據 ID 獲取
curl http://localhost:8080/api/users/1

# 搜索用戶
curl "http://localhost:8080/api/users/search?name=John"
```

### 更新用戶 (寫操作)

```bash
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_updated",
    "email": "john.updated@example.com",
    "firstName": "John",
    "lastName": "Smith"
  }'
```

### 檢查數據庫連接

```bash
curl http://localhost:8080/api/health/db
```

## 監控和日誌

### 查看讀寫路由

應用日誌會顯示數據庫操作。在配置文件中已啟用 SQL 日誌：

```yaml
spring:
  jpa:
    show-sql: true
    properties:
      hibernate:
        format_sql: true
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

### Actuator 端點

- `GET /actuator/health` - 健康檢查批准端點

## 配置說明

### 數據源配置

在 `application.yml` 中配置了三個數據源：

- **primary**: 主數據庫，處理所有寫操作
- **replica1**: 第一個副本數據庫，處理讀操作
- **replica2**: 第二個副本數據庫，處理讀操作

每個數據源都配置了 HikariCP 連接池。

### 環境變量

在 Docker 環境中，可以通過環境變量覆蓋配置：

```bash
SPRING_DATASOURCE_PRIMARY_JDBC_URL=jdbc:postgresql://postgres-primary:5432/mydb
SPRING_DATASOURCE_REPLICA1_JDBC_URL=jdbc:postgresql://postgres-replica1:21/mydb
SPRING_DATASOURCE_REPLICA2_JDBC_URL=jdbc:postgresql://postgres-replica2:5432/mydb
```

## 注意事項

1. **Replication 設置**: 本示例使用了簡化的 replication 設置。在生產環境中，建議使用更可靠的方案如 Patroni 或 pgpool-II

2. **事務管理**: 讀操作使用 `@Transactional(readOnly = true)` 會被路由到 Replica，寫操作會路由到 Primary

3. **連接池**: 建議根據實際負載調整 HikariCP 連接池大小

4. **數據一致性**: 由於 Replication 是異步的，讀 Replica 可能會看到稍微過時的數據

## 故障排除

### PostgreSQL 連接問題

```bash
# 檢查容器狀態
docker-compose ps

# 檢查數據庫日誌
docker-compose logs postgres-primary
```

### 應用無法連接數據庫

1. 確保所有 PostgreSQL 容器都在運行
2. 檢查網絡連接：`docker network inspect spring-boot-primary-replica-db-example_db_network`
3. 檢查應用日誌：`docker-compose logs app`

## 許可證

MIT

## 貢獻

歡迎提交 Issue 和 Pull Request！

