# ========================
# Stage 1: 빌드 스테이지
# ========================
FROM node:22-alpine AS builder

WORKDIR /build

# 의존성 파일 먼저 복사 (캐시 활용)
COPY package.json package-lock.json ./
RUN npm ci

# 소스 코드 복사 및 빌드
COPY . .

# 빌드 모드 (development | production)
ARG BUILD_ENV=development
RUN npm run build:${BUILD_ENV}

# ========================
# Stage 2: nginx 서빙
# ========================
FROM nginx:stable-alpine

# 타임존 설정 디폴트 UTC
# RUN apk add --no-cache tzdata && \
#     cp /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
#     echo "Asia/Seoul" > /etc/timezone

# 빌드 결과물 복사
COPY --from=builder /build/dist /usr/share/nginx/html

# nginx 설정 복사
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
