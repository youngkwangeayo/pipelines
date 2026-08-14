# NanoPortalAPI — 클라우드 포털 백엔드 (Node + TypeScript + Express)
#
# 빌드 (@nextpay/* 는 public Bitbucket repo, package.json 에 git+https 명시 → SSH 키 불필요):
#   docker build -t nano-portal-api .
#
# 실행: 배포는 infra/compose.yml 로 한다 (설정·볼륨·네트워크 정의는 그쪽이 단일 출처).
#   cd /opt/nano-portal-api && docker compose up -d      # 자세한 내용은 infra/README.md
#
# 포트는 3001 하나로 고정한다 — 이미지 ENV·EXPOSE·compose publish·헬스체크가 모두 3001.
# 컨테이너를 비루트(uid 1000)로 실행하므로 특권 포트(<1024)는 바인딩할 수 없다.
# conf 의 SERVICE_PORT 는 앱 개발자의 로컬 실행용이며, 컨테이너에서는 이미지 ENV 가
# 이미 설정돼 있어 dotenv 가 덮지 않으므로 항상 3001 이 된다.
#
# 로컬 단독 실행 예 (설정 파일을 env 로 주입, 볼륨 없이):
#   docker run --rm -p 3001:3001 --env-file ./nano-portal-api.conf nano-portal-api

########################  Builder  ########################
FROM node:20-bookworm-slim AS builder
WORKDIR /app

# 네이티브 모듈(bcrypt) 컴파일용 툴체인 + git 의존성 clone 용 git
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 make g++ git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# @nextpay/* 는 public Bitbucket repo — package.json 에 git+https 로 명시되어 SSH 키 없이 익명 clone.
# (커밋 해시는 락파일에 고정돼 재현성 유지)
COPY package.json package-lock.json ./
RUN npm ci

# 소스 컴파일: tsc → dist/, 이어서 tsc-alias 가 @lib 등 경로 별칭을 상대경로로 치환
# (덕분에 런타임에 tsconfig-paths 리졸버가 필요 없음 → node dist/index.js 로 바로 실행)
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Swagger 는 런타임에 src/**/*.yml 을 읽는다. tsc 는 non-ts 를 dist 로 옮기지 않으므로 별도 스테이징
RUN mkdir -p /app/assets \
    && find src -name '*.yml' -exec cp --parents {} /app/assets/ \;

# 설치된 node_modules 에서 devDependencies 제거 (bcrypt 네이티브 컴파일 결과는 유지됨)
RUN npm prune --omit=dev

########################  Runner  ########################
FROM node:20-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production

# 배포 태그를 이미지에 굽는다 → Swagger info.version 에 노출되어 "지금 뜬 게 어느 버전인지" 를
# 컨테이너 밖에서 확인할 수 있다. 파이프라인이 --build-arg API_VERSION=$BITBUCKET_TAG 로 넘긴다.
# 기본값을 비워 두는 이유: 인자 없이 빌드한 이미지가 특정 버전인 척하지 않게 한다.
ARG API_VERSION=
ENV API_VERSION=${API_VERSION}
# 컨테이너 리슨 포트의 기준값. dotenv 는 이미 존재하는 환경변수를 덮지 않으므로(override 기본 false)
# 마운트된 conf 에 SERVICE_PORT 가 있어도 이 값이 유지된다.
ENV SERVICE_PORT=3001

# tini: PID 1 신호 처리 — 앱이 SIGTERM/SIGINT 에서 DB/Redis/MQTT 연결 정리(graceful shutdown)
RUN apt-get update && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

# 프로덕션 의존성만 이관 (dev 제거됨). bcrypt 네이티브는 동일 베이스라 호환
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/assets/src ./src
COPY --chown=node:node package.json ./

# 런타임 쓰기 경로 (프로덕션에선 볼륨으로 마운트)
RUN mkdir -p uploads logs && chown -R node:node uploads logs

# 비루트 실행: node 베이스 이미지에 기본 포함된 node 유저(uid/gid 1000).
# 리슨 포트를 비특권(3001)으로 두어 CAP_NET_BIND_SERVICE 없이 바인딩된다.
USER node

# 컨테이너 리슨 포트 (위 ENV SERVICE_PORT 와 동일)
EXPOSE 3001
VOLUME ["/app/uploads", "/app/logs"]

# 별칭이 빌드타임에 상대경로로 치환됐으므로 리졸버 없이 바로 실행
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "dist/index.js"]
