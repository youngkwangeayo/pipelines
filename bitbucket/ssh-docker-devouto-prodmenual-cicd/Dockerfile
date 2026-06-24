# ============================================
# visionai_backend — Express REST API (포트 3000)
# ============================================
# 의존성 전략: node_modules 벤더링.
#   사내 private dep(@nextpay/* = bitbucket:nextpayments/...)을 이미지 빌드 중에
#   git 으로 클론하지 않는다 — 빌드 컨텍스트에 이미 설치된 node_modules 를 COPY 한다.
#   따라서 docker build 이전에 호스트(CI 스텝)에서 `npm ci` 로 node_modules 가
#   준비돼 있어야 한다. (.dockerignore 가 node_modules 를 제외하지 않는 이유)
#
#   ※ bcrypt 등 native 모듈이 있으므로 호스트 npm ci 환경(glibc)과 런타임 이미지를
#     맞춘다 — node:22-slim(debian/glibc). alpine(musl)으로 바꾸면 바이너리 불일치.

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

# Swagger 스펙 YAML 복사 (swagger.ts 가 ./src/... 상대경로로 스캔)
COPY --from=builder /app/src/config/swagger-*.yml ./src/config/
COPY --from=builder /app/src/restapi/*.yml ./src/restapi/

# 로그는 winston-daily-rotate-file 가 /app/logs 에 기록.
# 배포 시 호스트 볼륨(-v /var/log/visionai_backend:/app/logs)을 마운트한다.
RUN mkdir -p logs

EXPOSE 3000

CMD ["node", "dist/index.js"]
