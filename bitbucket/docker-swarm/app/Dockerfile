# ========================
# Stage 1: 빌드 스테이지
# ========================
FROM golang:1.25-alpine AS builder

# 빌드에 필요한 도구 설치
RUN apk add --no-cache git ca-certificates

# 작업 디렉토리 설정
WORKDIR /build

# 의존성 파일 먼저 복사 (캐시 활용을 위해 소스보다 먼저 복사)
COPY go.mod go.sum ./
RUN go mod download

# 전체 소스 코드 복사
COPY . .

# Go 바이너리 빌드
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server cmd/server/main.go

# ========================
# Stage 2: 런타임 스테이지
# ========================
FROM alpine:latest AS runtime


# 필수 패키지 설치
RUN apk add --no-cache ca-certificates tzdata curl

# 타임존 설정 (Asia/Seoul)
ENV TZ=Asia/Seoul
RUN cp /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
    echo "Asia/Seoul" > /etc/timezone

# 보안을 위해 루트가 아닌 사용자 생성
# UID/GID 1000은 일반적인 비루트 사용자 ID입니다.
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

# 작업 디렉토리 설정
WORKDIR /app


# 빌드 스테이지에서 컴파일된 바이너리 복사
# 빌드 스테이지에서 정적 리소스 복사
COPY --from=builder /build/server .
COPY --from=builder /build/static ./static


# 로그, 업로드 디렉토리 생성 및 권한 설정
RUN mkdir -p log && chown -R appuser:appgroup /app/log
RUN mkdir -p uploads && chown -R appuser:appgroup /app/uploads

# 바이너리 실행 권한 부여
RUN chmod +x /app/server

# 전체 앱 디렉토리 소유권 변경
RUN chown -R appuser:appgroup /app

# 비루트 사용자로 전환 (보안 강화)
USER appuser

# 포트 노출 (8085번 포트에서 서비스)
EXPOSE 8085

# 애플리케이션 실행
# dumb-init 없이 직접 실행 (Alpine의 기본 init으로 충분)
CMD ["./server"]
