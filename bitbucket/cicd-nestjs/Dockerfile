# ================================
# Build Stage
# ================================
FROM node:20-alpine AS builder

WORKDIR /app

# bcrypt 빌드에 필요한 패키지 설치
RUN apk add --no-cache python3 make g++

# 의존성 먼저 설치 (캐시 활용)
COPY package*.json ./
RUN npm ci

# 소스 복사 및 빌드
COPY . .
RUN npm run build

# devDependencies 제거
RUN npm ci --only=production && npm cache clean --force

# ================================
# Production Stage
# ================================
FROM node:20-alpine AS production

WORKDIR /app

# 보안: non-root 사용자 생성
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

# 빌드 결과물 복사
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/package.json ./

# 런타임에 앱이 /app 하위에 파일/폴더를 생성할 수 있으므로 소유권 변경
RUN chown -R nestjs:nodejs /app

# non-root 사용자로 전환
USER nestjs

# 포트 노출
EXPOSE 3003

# 헬스체크
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3003/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# 실행
CMD ["node", "dist/main"]
