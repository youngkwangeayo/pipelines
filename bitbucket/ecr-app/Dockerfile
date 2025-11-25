# ========================
# Stage 1: deps
# ========================
FROM node:22-alpine AS deps

WORKDIR /cms

COPY package*.json yarn.lock* ./
RUN yarn install --production --frozen-lockfile --no-cache

# ========================
# Stage 2: runtime
# ========================
FROM node:22-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3849 \
    TZ=Asia/Seoul

WORKDIR /cms

RUN apk add --no-cache dumb-init curl ca-certificates openssl
RUN mkdir -p /cms/logs/entrypoint && chown -R node:node /cms/logs
RUN mkdir -p /cms/adjustfile && chown -R node:node /cms/adjustfile



# Copy dependencies
COPY --chown=node:node --from=deps /cms/node_modules ./node_modules
COPY --chown=node:node . .

# 정확한 환경용 엔진 바이너리 추가
RUN npx prisma generate && chown -R node:node /cms/prisma

# Copy certificates (권한 강화)
COPY --chown=node:node config/ ./config/
RUN chmod 600 /cms/config/*.pem.crt && \
    chmod 600 /cms/config/*.key && \
    chmod 644 /cms/config/AmazonRootCA1.pem

# 런타임 시작 스크립트 추가
COPY infra/entrypoint.sh ./
RUN chmod +x /cms/entrypoint.sh

USER node

EXPOSE 3827

ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "/cms/entrypoint.sh"]
