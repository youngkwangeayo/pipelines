#!/bin/sh
set -e

LOG_DIR="/app/logs/entrypoint"
ERROR_LOG="$LOG_DIR/error-$(date +%Y-%m-%d).log"
INFO_LOG="$LOG_DIR/info-$(date +%Y-%m-%d).log"

# 로그 디렉토리 생성
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi

# 부팅요청
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
echo "{\"timestamp\":\"${TIMESTAMP}\",\"level\":\"info\",\"subject\":\"app boot\",\"message\":\"CoffeeZip CMS application boot request received. Starting app on port ${PORT}\"}" >> "$INFO_LOG"

# Prisma pull 실행 및 결과 캡처
if output=$(npx prisma db pull 2>&1); then
  npx prisma generate
else

  # 현재 UTC 타임스탬프
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

  # JSON 포맷으로 에러 로그 추가
  echo "{\"timestamp\":\"${TIMESTAMP}\",\"level\":\"error\",\"subject\":\"prisma pull error\",\"message\":\"$(echo "$output" | sed 's/"/\\"/g' | tr -d '\n')\"}" >> "$ERROR_LOG"

fi

# 서버 실행 정보 로그 기록
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
echo "{\"timestamp\":\"${TIMESTAMP}\",\"level\":\"info\",\"subject\":\"server start\",\"message\":\"CoffeeZip CMS server started successfully on port ${PORT}\"}" >> "$INFO_LOG"

exec node src/index.js
