FROM gradle:8.9-jdk21 AS build

WORKDIR /app

# 複製 Gradle 配置文件
COPY build.gradle.kts settings.gradle.kts ./

# 複製源代碼
COPY src ./src

# 構建應用
RUN gradle clean build -x test --no-daemon

# 運行階段
FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

# 從構建階段複製 JAR 文件
COPY --from=build /app/build/libs/*.jar app.jar

# 暴露端口
EXPOSE 8080

# 運行應用
ENTRYPOINT ["java", "-jar", "app.jar"]

