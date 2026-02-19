
# ============================================================

# --- 환경별 임포트 ---
include infra/signage-manager/version.env
export $(shell sed 's/=.*//' infra/signage-manager/version.env)


# --- 파라미터 (make 실행 시 오버라이드) ---
ENV ?=
STACK ?=
TAG ?=
SSH_HOST ?=

# --- 상수 ---
AWS_REGION     := ap-northeast-2
AWS_ACCOUNT_ID := 365485194891
ECR_REGISTRY   := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

ALLOWED_ENVS    := dev prod local
ALLOWED_STACKS  := signage-manager monitoring


.PHONY: help connect init build deploy validate rm restart ps ls logs

# ============================================================
# connect - 원격 Docker 호스트에 SSH로 연결 로컬에서 사용하기.
# ============================================================
connect:
	@if [ -z "$(SSH_HOST)" ]; then \
		echo "❌ [Error] SSH_HOST를 지정해주세요."; \
		echo "   👉 예) make connect SSH_HOST=본인ssh config hostname"; \
		exit 1; \
	fi
	@echo "[connect] Docker context 생성: $(SSH_HOST)..."
	@docker context create $(SSH_HOST) --docker "host=ssh://$(SSH_HOST)" 2>/dev/null || true
	@echo "[connect] Docker context 전환: $(SSH_HOST)"
	@docker context use $(SSH_HOST)
	@echo "[connect] 완료 — 현재 context: $(SSH_HOST)"

# ============================================================
# help (기본)
# ============================================================
help:
	@echo "사용법:"
	@echo "  make init                              Docker Swarm 초기화 + ECR 로그인"
	@echo "  make build    ENV=local STACK=signage-manager   로컬 빌드"
	@echo "  make deploy   ENV=dev   STACK=signage-manager   스택 배포"
	@echo "  make rm       ENV=dev   STACK=signage-manager   스택 제거"
	@echo "  make restart  ENV=dev   STACK=signage-manager   서비스 재시작 (SVC=sm 으로 개별 지정 가능)"
	@echo "  make ps                                         전체 서비스 태스크 상태"
	@echo "  make ls                                         전체 서비스 목록"
	@echo "  make logs     ENV=dev   STACK=signage-manager SVC=sm   서비스 로그 확인"


# ============================================================
# init - Docker 데몬 확인 + ECR 로그인
# ============================================================
init:
	@echo "[init] Docker 데몬 확인..."
	@docker info > /dev/null 2>&1 || (echo "Error: Docker가 실행되고 있지 않습니다." && exit 1)
	@echo "[init] Docker 데몬 정상"
	# 이미 init 되어있어도 에러 내지 않고 넘어가도록 '|| true' 추가
	@docker swarm init 2>/dev/null || true
	@echo "[init] Docker Swarm 정상"
	@echo "[init] ECR 로그인..."
	@aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_REGISTRY)
	@echo "[init] ECR 로그인 완료"


# ============================================================
#  유효성 검사
# ============================================================
validate:
	@if [ -z "$(filter $(STACK),$(ALLOWED_STACKS))" ]; then \
		echo "❌ [Error] 유효하지 않은 스택입니다: '$(STACK)'"; \
		echo "   👉 허용된 목록: $(ALLOWED_STACKS)"; \
		exit 1; \
	fi
	@if [ -z "$(filter $(ENV),$(ALLOWED_ENVS))" ]; then \
		echo "❌ [Error] 유효하지 않은 환경: '$(ENV)'"; \
		echo "   👉 허용된 목록: $(ALLOWED_ENVS)"; \
		exit 1; \
	fi
	@echo "✅ [Validate] 검증 통과: $(ENV)-$(STACK)"

# ============================================================
# 빌드 (Build)
# ============================================================
build: validate
	@if [ "$(ENV)" != "local" ]; then \
		echo "❌ [Build Error] 빌드는 'local' 환경에서만 테스트 가능합니다."; \
		exit 1; \
	fi
	@echo "🏗️ [build] $(ENV) 환경 빌드 시작..."
	@docker compose \
		-f infra/$(STACK)/docker-compose.yaml \
		-f infra/$(STACK)/docker-compose-$(ENV).yaml \
		build

# ============================================================
# 배포 환경별
# ============================================================
deploy: validate
	@echo "🚀 [Deploy] $(STACK) 배포 시작..."
	@docker stack deploy --with-registry-auth \
		-c infra/$(STACK)/docker-compose.yaml \
		-c infra/$(STACK)/docker-compose-$(ENV).yaml \
		$(ENV)-$(STACK)

# ============================================================
# rm - 스택 제거
# ============================================================
rm: validate
	@echo "[rm] 스택 제거: $(ENV)-$(STACK)"
	@docker stack rm $(ENV)-$(STACK)
	@echo "[rm] 완료 (볼륨은 유지됩니다)"

# ============================================================
# restart - 서비스 롤링 재시작
# ============================================================
restart: validate
ifeq ($(SVC),)
	@echo "[restart] 전체 서비스 재시작: $(ENV)-$(STACK)"
	@for svc in $$(docker stack services --format '{{.Name}}' $(ENV)-$(STACK)); do \
		echo "[restart] $$svc 재시작"; \
		docker service update --force $$svc; \
	done
else
	@echo "[restart] $(ENV)-$(STACK)_$(SVC) 재시작"
	@docker service update --force $(ENV)-$(STACK)_$(SVC)
endif

# ============================================================
# ps - 전체 서비스 태스크 상태
# ============================================================
ps:
	@docker service ps $$(docker service ls -q)

# ============================================================
# ls - 전체 서비스 목록
# ============================================================
ls:
	@docker service ls

# ============================================================
# logs - 로그 확인
# ============================================================
logs: validate
ifeq ($(SVC),)
	@echo "❌ [Error] SVC를 지정해주세요."
	@echo "   👉 예) make logs ENV=dev STACK=signage-manager SVC=sm"
	@exit 1
else
	@docker service logs -f --tail=100 $(ENV)-$(STACK)_$(SVC)
endif
