# ========================
# Stage 1: deps
# ========================
FROM node:22-alpine AS deps

WORKDIR /app

COPY package*.json yarn.lock* ./

RUN yarn install --production --frozen-lockfile --no-cache

# ========================
# Stage 2: runtime
# ========================
FROM node:22-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3849 \
    TZ=Asia/Seoul

RUN apk add --no-cache dumb-init curl ca-certificates openssl

RUN mkdir -p /app/logs/entrypoint && chown -R node:node /app/logs

WORKDIR /app

# Copy dependencies
COPY --from=deps /app/node_modules ./node_modules
COPY src ./src
COPY docs ./docs
COPY public ./public
COPY package*.json ./

# Copy Prisma schema (used by runtime db pull)
# 정확한 환경용 엔진 바이너리 추가
COPY prisma ./prisma
RUN npx prisma generate && chown -R node:node /app/prisma

# Copy certificates (권한 강화)
COPY --chown=node:node certs/ ./certs/
RUN chmod 600 /app/certs/coffeezip-cms-certificate.pem.crt && \
    chmod 600 /app/certs/*.key && \
    chmod 644 /app/certs/AmazonRootCA1.pem

# 런타임 시작 스크립트 추가
COPY infra/entrypoint.sh ./
RUN chmod +x /app/entrypoint.sh

USER node

EXPOSE 3849

ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "/app/entrypoint.sh"]
