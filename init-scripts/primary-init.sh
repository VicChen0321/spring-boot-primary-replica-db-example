#!/bin/bash
set -e

# 初始化腳本 - 確保權限正確
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    -- 授予權限
    GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;
EOSQL

