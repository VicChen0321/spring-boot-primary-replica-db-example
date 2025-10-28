.PHONY: build up down logs clean test

# 構建並啟動所有服務
up:
	docker-compose up -d

# 停止所有服務
down:
	docker-compose down

# 停止服務並刪除數據卷
clean:
	docker-compose down -v
	docker system prune -f

# 查看日誌
logs:
	docker-compose logs -f app

# 查看所有服務日誌
logs-all:
	docker-compose logs -f

# 重新構建並啟動
rebuild:
	docker-compose down
	docker-compose up -d --build

# 檢查服務狀態
status:
	docker-compose ps

# 進入應用容器
shell-app:
	docker exec -it spring-boot-app /bin/bash

# 進入 Primary 數據庫
shell-db-primary:
	docker exec -it postgres-primary psql -U myuser -d mydb

# 進入 Replica 1 數據庫
shell-db-replica1:
	docker exec -it postgres-replica1 psql -U myuser -d mydb

# 進入 Replica 2 數據庫
shell-db-replica2:
	docker exec -it postgres-replica2 psql -U myuser -d mydb

# 本地構建
build-local:
	./gradlew clean build -x test

# 本地運行
run-local:
	./gradlew bootRun

# 運行測試
test:
	./gradlew test

