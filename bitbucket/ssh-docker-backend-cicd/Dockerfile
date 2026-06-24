# Sony CountHub — Kinesis 컨슈머 워커 (HTTP 서버 아님, dist/index.js 단일 프로세스)
#
# 의존성 전략: node_modules 벤더링.
#   사내 private dep(@nextpay/mysql = bitbucket:nextpayments/node_mysql)을
#   이미지 빌드 중에 git 으로 클론하지 않는다 — 빌드 컨텍스트에 이미 설치된
#   node_modules 를 COPY 한다. 따라서 docker build 이전에 호스트(또는 CI 스텝)에서
#   `npm ci` 로 node_modules 가 준비돼 있어야 한다. (.dockerignore 가 node_modules 를
#   제외하지 않는 이유)

# ---- builder: TS 컴파일 + dev 의존성 제거 ----
FROM node:22-slim AS builder
WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./
COPY node_modules ./node_modules
COPY src ./src

# tsc + tsc-alias (alias 를 상대경로로 재작성 → 런타임에 tsconfig-paths 불필요)
RUN npm run build \
    # 빌드 후 devDependencies(typescript, tsc-alias 등) 제거 → 런타임 이미지 슬림화.
    # 네트워크 없이 기존 node_modules 에서 제거만 수행한다.
    && npm prune --omit=dev

# ---- runner: 런타임만 ----
FROM node:22-slim AS runner
ENV NODE_ENV=production
WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json

# 로그는 LOG_DIR(기본 logs → /app/logs)로 winston-daily-rotate-file 가 기록.
# 배포 시 호스트 볼륨(-v /var/log/...:/app/logs)을 마운트한다.
# (마운트 대상이 root 소유라 컨테이너는 root 로 실행 — 별도 USER 미지정)

CMD ["node", "dist/index.js"]
