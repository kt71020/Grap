# PostgreSQL 設定指南

## 🐘 PostgreSQL 安裝和設定

### 1. 安裝 PostgreSQL

#### macOS (使用 Homebrew)

```bash
brew install postgresql
brew services start postgresql
```

#### Ubuntu/Debian

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### CentOS/RHEL

```bash
sudo yum install postgresql postgresql-server postgresql-contrib
sudo postgresql-setup initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### 2. 建立資料庫和用戶

```bash
# 切換到 postgres 用戶
sudo -u postgres psql

# 或直接執行指令
sudo -u postgres createdb upload_db
sudo -u postgres psql -c "CREATE USER upload_user WITH PASSWORD 'upload_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE upload_db TO upload_user;"
sudo -u postgres psql -c "ALTER USER upload_user CREATEDB;"  # 如果需要建立測試資料庫
```

### 3. 設定 PostgreSQL 認證

編輯 `pg_hba.conf` 檔案：

```bash
# 找到設定檔位置
sudo -u postgres psql -c "SHOW hba_file;"

# 編輯設定檔
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

加入或修改以下行：

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   upload_db       upload_user                             md5
host    upload_db       upload_user     127.0.0.1/32            md5
host    upload_db       upload_user     ::1/128                 md5
```

重新載入設定：

```bash
sudo systemctl reload postgresql
```

### 4. 測試連線

```bash
# 測試連線
psql -h localhost -U upload_user -d upload_db

# 或使用完整連線字串
psql "postgresql://upload_user:upload_password@localhost:5432/upload_db"
```

## 📊 資料表結構

```sql
CREATE TABLE processing_jobs (
    id SERIAL PRIMARY KEY,
    process_id VARCHAR(50) UNIQUE NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'processing', 'completed', 'failed'
    progress VARCHAR(10), -- '50%'
    shop_id INTEGER,
    version INTEGER DEFAULT 4,
    regional_count INTEGER,
    regional_ids TEXT, -- JSON array
    messages TEXT, -- JSON array
    current_messages TEXT, -- JSON array for current status
    error_messages TEXT, -- JSON array
    error_count INTEGER DEFAULT 0,
    validation_details TEXT, -- JSON object
    csv_content TEXT, -- JSON array
    analysis TEXT, -- JSON object
    auth_token TEXT,
    filename TEXT,
    estimated_completion TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX idx_process_id ON processing_jobs(process_id);
CREATE INDEX idx_status ON processing_jobs(status);
CREATE INDEX idx_created_at ON processing_jobs(created_at);
```

## ⚙️ Dancer2 設定

在 `config.yml` 中設定：

```yaml
plugins:
  Database:
    driver: 'Pg'
    database: 'upload_db'
    host: 'localhost'
    port: 5432
    username: 'upload_user'
    password: 'upload_password'
    connection_check_threshold: 10
    dbi_params:
      RaiseError: 1
      AutoCommit: 1
      pg_enable_utf8: 1
```

## 🔧 維護指令

### 檢查資料庫狀態

```sql
-- 查看所有處理工作
SELECT process_id, status, progress, created_at, updated_at
FROM processing_jobs
ORDER BY created_at DESC;

-- 查看進行中的工作
SELECT * FROM processing_jobs WHERE status = 'processing';

-- 清理過期工作 (超過 7 天)
DELETE FROM processing_jobs
WHERE created_at < NOW() - INTERVAL '7 days'
AND status IN ('completed', 'failed');
```

### 效能監控

```sql
-- 查看資料表大小
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE tablename = 'processing_jobs';

-- 查看索引使用情況
SELECT
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname = 'processing_jobs';
```

## 🚀 部署檢查清單

- [ ] PostgreSQL 服務已啟動
- [ ] 資料庫 `upload_db` 已建立
- [ ] 用戶 `upload_user` 已建立並有適當權限
- [ ] `pg_hba.conf` 設定正確
- [ ] 防火牆允許 5432 端口（如果遠端連線）
- [ ] Perl DBD::Pg 模組已安裝
- [ ] 資料表已建立
- [ ] 連線測試成功

## 🔒 安全建議

1. **密碼安全**：使用強密碼，定期更換
2. **網路安全**：限制資料庫存取來源
3. **權限最小化**：只給予必要的資料庫權限
4. **備份策略**：定期備份資料庫
5. **日誌監控**：監控資料庫存取日誌

## 📈 效能優化

1. **連線池**：使用連線池減少連線開銷
2. **索引優化**：根據查詢模式調整索引
3. **定期清理**：清理過期資料
4. **監控查詢**：使用 `pg_stat_statements` 監控慢查詢

```sql
-- 啟用查詢統計
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 查看慢查詢
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```
