# syntax=docker/dockerfile:1.7
# ─────────────────────────────────────────────────────────────
# AI-Hub API — 멀티스테이지 빌드
#  builder : 의존성 설치 + tsc 컴파일 + tsc-alias(경로 alias→상대경로) + devDeps prune
#  runtime : dist + prod node_modules + swagger .yml 만 담은 슬림 실행 이미지
# ─────────────────────────────────────────────────────────────

# ===== 1) builder =====
FROM node:22-alpine AS builder
WORKDIR /app

# git        : @nextpay/* 사내 bitbucket git 의존성 clone 용
# python3/g++ : bcrypt 네이티브 모듈 빌드 (alpine=musl, prebuilt 없을 때)
RUN apk add --no-cache git python3 make g++

ENV NODE_ENV=development

# package.json + lockfile 먼저 복사 → 의존성 레이어 캐시 (lockfile 기준 npm ci)
COPY package.json package-lock.json ./
# NOTE: 사내 bitbucket 의존성이 private 라 인증이 필요해지면 아래로 교체:
#   RUN --mount=type=ssh mkdir -p ~/.ssh \
#       && ssh-keyscan bitbucket.org >> ~/.ssh/known_hosts && npm ci
RUN npm ci

# 소스 복사 후 빌드 (tsc → dist, tsc-alias → @lib 등 alias 를 상대경로로 재작성)
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# 런타임용으로 devDependencies 제거 (tsc-alias·ts-node·@types 등 탈락)
RUN npm prune --omit=dev


# ===== 2) runtime =====
FROM node:22-alpine AS runtime
WORKDIR /app
# SERVICE_PORT 는 .env(/etc/ai-hub-api.conf) 와 동일하게 8093 로 통일 (env-file 로 덮어쓸 수 있음)
ENV NODE_ENV=production \
    SERVICE_PORT=8093

# 빌드 메타 — Swagger info.version·에이전트 /agent/manifest.json·/llms.txt 스탬프용. CI 가 --build-arg 로 주입.
# API_VERSION = 배포 태그(dev-X.Y.Z → X.Y.Z). 이미지에 구워지므로 .env 없이도 배포본이 버전을 안다.
# 런타임 --env-file 로 API_VERSION 을 주면 그 값이 우선(ops override). 미주입 시 앱이 package.json 으로 폴백.
ARG BUILD_SHA=unknown
ARG BUILD_TIME=unknown
ARG API_VERSION=
ENV BUILD_SHA=$BUILD_SHA \
    BUILD_TIME=$BUILD_TIME \
    API_VERSION=$API_VERSION

# 빌드 산출물 + prod 의존성만
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json

# swagger-jsdoc 가 CWD 기준 './src/**/*.yml' 을 읽으므로 src 경로 구조 그대로 복사
# (tsc 는 .yml 을 dist 로 옮기지 않음 — 이게 없으면 /docs 스펙이 빈 채로 뜸)
# restapi 는 코드 glob 이 재귀(**)라 디렉터리 통째 복사 — 하위 폴더에 yml 을 둬도 이미지에서 누락되지 않도록.
# (swagger 는 코드 glob 이 비재귀 '*.yml' 이라 파일 glob 로 충분.)
COPY src/lib/swagger/*.yml ./src/lib/swagger/
COPY src/restapi           ./src/restapi

# 에이전트용 문서 — 서버가 /agent/*·/llms.txt 로 라이브 서빙(CWD 기준 읽음).
# 이미지가 자기 코드와 일치하는 계약을 스스로 지니도록 함께 굽는다.
COPY AGENTS.md   ./AGENTS.md
COPY docs/agent  ./docs/agent

# 배포 세트 참조 문서(가이드·enum) — /guides 로 정적 서빙(express.static('guides')). 필드 SoT /openapi.json 은 코드 생성.
COPY guides  ./guides

# 로그 디렉토리 (winston daily-rotate). non-root 로 실행하므로 소유권 부여.
RUN mkdir -p logs/errors && chown -R node:node /app
USER node

# 컨테이너 listen 포트 = SERVICE_PORT(8093). EXPOSE 는 문서용.
EXPOSE 8093

CMD ["node", "dist/index.js"]
