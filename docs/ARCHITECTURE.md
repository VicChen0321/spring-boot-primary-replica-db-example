# 系統架構說明

## 架構概述

這是一個實現 PostgreSQL 讀寫分離的 Spring Boot 應用示例，使用 1 個 Primary 數據庫和 2 個 Replica 數據庫。

## 組件說明

### 數據庫層

#### Primary 數據庫 (端口 5432)
- 負責所有寫操作（INSERT, UPDATE, DELETE）
- 主數據源
- 數據的權威來源

#### Replica 1 和 Replica 2 (端口 5433, 5434)
- 負責所有讀操作（SELECT）
- 實現負載均衡
- 提高讀取性能

### 應用層

#### 核心配置類

**DataSourceConfig**
- 配置三個獨立的數據源
- 創建路由數據源
- 實現讀寫分離邏輯

**ReplicationRoutingDataSource**
- 自定義路由邏輯
- 根據操作類型（讀/寫）選擇數據源
- 讀操作隨機選擇 Replica 1 或 Replica 2

**DataSourceAspect**
- AOP 切面
- 攔截 `@Transactional` 方法
- 根據 `readOnly` 屬性設置數據源類型

**ReplicationContextHolder**
- 線程本地變量
- 存儲當前的讀寫類型
- 線程安全

### 業務層

#### Entity
- **User**: 用戶實體類
  - 包含基本的用戶信息
  - 使用 JPA 註解

#### Repository
- **UserRepository**: 數據訪問層
  - 繼承 JpaRepository
  - 自定義查詢方法

#### Service
- **UserService**: 業務邏輯層
  - 實現 CRUD 操作
  - 使用 `@Transactional` 註解控制讀寫

#### Controller
- **UserController**: REST API 端點
  - 提供用戶管理的完整 API
  - **HealthController**: 健康檢查端點

## 讀寫分離流程

### 寫操作流程

1. 客戶端發送 POST/PUT/DELETE 請求
2. Controller 調用 Service 方法
3. `DataSourceAspect` 檢測到非 `readOnly` 的 `@Transactional`
4. 設置 `ReplicationContextHolder` 為 "WRITE"
5. `ReplicationRoutingDataSource` 路由到 Primary 數據庫
6. 執行寫操作

### 讀操作流程

1. 客戶端發送 GET 請求
2. Controller 調用 Service 方法
3. `DataSourceAspect` 檢測到 `readOnly=true` 的 `@Transactional`
4. 設置 `ReplicationContextHolder` 為 "READ"
5. `ReplicationRoutingDataSource` 隨機選擇 Replica 1 或 Replica 2
6. 執行讀操作

## 技術決策

### 為什麼使用 AOP 而不是手動切換？

- **自動化**: 無需在每個方法中手動設置
- **透明性**: 業務代碼保持簡潔
- **一致性**: 確保所有操作都經過正確的路由
- **易於維護**: 集中管理路由邏輯

### 為什麼使用 ThreadLocal？

- **線程安全**: 每個線程獨立的上下文
- **避免參數傳遞**: 不需要修改方法簽名
- **自動清理**: 請求結束後自動清理
- **性能**: 本地變量訪問速度快

### 為什麼隨機選擇 Replica？

- **負載均衡**: 均勻分發讀操作
- **簡單實現**: 不需要複雜的選擇算法
- **足夠有效**: 對於大多數場景已經足夠

## 優點

1. **性能提升**: 讀操作分散到多個數據庫
2. **高可用性**: 讀操作可以在 Replica 故障時切換
3. **擴展性**: 可以輕鬆添加更多 Replica
4. **透明性**: 業務代碼無需關心數據源切換
5. **易於維護**: 配置集中，邏輯清晰

## 注意事項

1. **數據一致性**: Replica 可能會有延遲（如果使用真正的 replication）
2. **事務管理**: 當前實現每個方法單獨的路由決策
3. **連接池**: 每個數據源都有獨立的連接池
4. **監控**: 建議添加監控以追蹤讀寫分布

## 擴展建議

### 生產環境改進

1. **真正的 Replication**: 使用 PostgreSQL 的流複製
2. **健康檢查**: 自動檢測 Replica 健康狀態
3. **故障切換**: 當 Replica 故障時自動切換到其他節點
4. **監控**: 添加 Prometheus metrics 和告警
5. **日誌**: 記錄每次路由決策用於分析

### 性能優化

1. **連接池調優**: 根據實際負載調整連接池大小
2. **緩存層**: 添加 Redis 減少數據庫負載
3. **分庫分表**: 如果數據量巨大
4. **讀寫分離策略**: 實現更智能的路由算法

## 圖表

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│      Spring Boot Application        │
│  ┌───────────────────────────────┐  │
│  │     UserController            │  │
│  └───────┬───────────────────────┘  │
│          │                           │
│          ▼                           │
│  ┌───────────────────────────────┐  │
│  │     UserService               │  │
│  │  @Transactional(readOnly)     │  │
│  └───────┬───────────────────────┘  │
│          │                           │
│          ▼                           │
│  ┌───────────────────────────────┐  │
│  │  DataSourceAspect (AOP)       │  │
│  └───────┬───────────────────────┘  │
│          │                           │
│          ▼                           │
│  ┌───────────────────────────────┐  │
│  │ ReplicationRoutingDataSource  │  │
│  │   (Read/Write Router)         │  │
│  └───┬───────────────┬───────────┘  │
└──────┼───────────────┼───────────────┘
       │               │
       ▼               ▼
┌──────────────┐ ┌──────────────┐
│   Primary    │ │   Replica 1  │
│   (WRITE)    │ │   Replica 2  │
│    5432      │ │  5433, 5434  │
└──────────────┘ └──────────────┘
```

