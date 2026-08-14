# RUNBOOK — NanoPortalAPI 운영 절차

배포·롤백·설정변경·장애대응 절차. 각 항목은 **UI(Bitbucket)** 와 **서버 수동** 두 가지 경로를 함께 적는다.
평상시에는 UI 경로를 쓰고, 파이프라인이 막혔거나 급할 때만 서버 수동으로 내려간다.

전제: 호스트 최초 준비(`bootstrap.sh` 실행, conf 배치, 공유 네트워크)는 끝나 있어야 한다 → [README.md](./README.md)

| 항목 | 값 |
|---|---|
| 컨테이너명 | `nano-portal-api` |
| 앱 디렉토리 | `/opt/nano-portal-api` |
| 포트 | 호스트 3001 → 컨테이너 3001 |
| 실행 계정 | 컨테이너 내부 `node` (uid 1000) |
| 이미지 | `$AWS_ECR_REPO/nano-portal-api:<태그>` |

---

## 1. 배포

### UI

1. 배포할 커밋에 semver 태그를 만든다 — Bitbucket **Commits** 화면에서 커밋 선택 → **Tag this commit** (`1.2.0`)
   ```bash
   # 또는 로컬에서
   git tag 1.2.0 && git push origin 1.2.0
   ```
2. **Pipelines** 에서 해당 태그 파이프라인이 시작된다.
   `Build & Push Image to ECR` → `Deploy to EC2 (DEV)` 까지 자동 진행.
3. DEV 확인 후 **PROD 승격** — 같은 파이프라인의 `Deploy to EC2 (PROD)` 스텝에서 **Run** 클릭.
4. **Deployments** 탭에서 각 환경의 현재 버전을 확인한다.

> PROD 스텝을 누르지 않으면 DEV 에만 배포된 상태로 남는다. 같은 이미지(`:1.2.0`)를 그대로 승격하므로 재빌드는 없다.

### 서버 수동

파이프라인이 막혔을 때. ECR 에 이미지가 이미 올라가 있어야 한다.

```bash
cd /opt/nano-portal-api

# 1) 배포할 태그 지정
sed -i 's/^IMAGE_TAG=.*/IMAGE_TAG=1.2.0/' .env

# 2) ECR 로그인 (인스턴스 프로파일 자격증명)
aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_REPO>

# 3) 교체
docker compose pull
docker compose up -d --remove-orphans

# 4) 확인
docker compose ps
docker compose logs --tail 50
curl -s localhost:3001/docs/swagger.json | head -c 120   # info.version 이 배포 태그와 같은지
```

---

## 2. 롤백

**전제: 릴리스마다 태그를 새로 발급할 것.** 롤백은 "이전 태그의 이미지가 남아 있다" 는 가정 위에서만
성립한다. 같은 태그(예: `0.0.1`)를 지웠다 다시 push 하며 덮어쓰면 이전 이미지는 태그를 잃고
`<none>` 이 되어 되돌릴 대상이 사라진다 (구성 검증 단계에서는 덮어써도 무방하나, 운영 배포는 새 태그로).

이미지 보존 범위:
- **호스트** — 배포 스텝이 매번 정리해 최신 10개(고유 ID)만 남긴다.
- **ECR** — 수명주기 정책이 없어 계속 쌓인다(덮어쓴 태그의 이미지는 untagged 로 남는다).

### UI

**Pipelines** 에서 되돌릴 버전의 태그 파이프라인을 찾아 해당 환경 배포 스텝을 **Rerun**.
이미지 빌드는 이미 끝나 있으므로 배포 스텝만 다시 돈다.

### 서버 수동

```bash
cd /opt/nano-portal-api
docker images | grep nano-portal-api        # 호스트에 남아 있는 태그 확인
sed -i 's/^IMAGE_TAG=.*/IMAGE_TAG=1.1.0/' .env
docker compose pull                         # 호스트에 없으면 ECR 에서 받는다
docker compose up -d
```

`up -d` 는 이미지 ID 가 바뀌었을 때만 컨테이너를 재생성한다. 같은 태그를 덮어쓴 경우에도
`pull` 로 ID 가 바뀌므로 정상적으로 교체된다.

---

## 3. 설정(conf) 변경

`/opt/nano-portal-api/config/nano-portal-api.conf` 가 컨테이너의 `/app/.env` 로 마운트되고
앱의 dotenv 가 기동할 때 읽는다. 따라서 파일을 고치고 재기동하면 반영된다.

```bash
sudo vi /opt/nano-portal-api/config/nano-portal-api.conf
cd /opt/nano-portal-api && docker compose up -d --force-recreate
docker compose logs --tail 30        # 기동 로그로 반영 확인
```

**`restart` 가 아니라 `up -d --force-recreate` 를 쓰는 이유**: 파일 하나를 바인드 마운트하면
그 마운트가 inode 에 묶인다. `vi`·`sed -i` 는 저장할 때 원본을 새 파일로 교체하므로(inode 변경)
컨테이너는 옛 내용을 계속 본다. 컨테이너를 재생성하면 마운트가 새로 잡혀 확실히 반영된다.
(에디터가 파일을 제자리에서 덮어썼다면 `docker compose restart` 로도 반영된다 —
확실히 하려면 항상 `--force-recreate`.)

주의:

- `SERVICE_PORT` 는 conf 에 있어도 **무시된다.** 이미지 ENV(3001)가 이미 설정돼 있고 dotenv 는
  기존 환경변수를 덮지 않는다. 포트를 바꾸려면 `Dockerfile` 과 `compose.yml` 을 함께 고쳐 재배포한다.
- 값 변경은 배포 이력에 남지 않는다. 무엇을 왜 바꿨는지는 별도로 기록할 것.
- conf 는 레포에 없다. 호스트를 새로 만들면 다시 배치해야 한다.

---

## 4. 상태 확인 / 로그

```bash
cd /opt/nano-portal-api

docker compose ps                       # 상태 + 헬스체크 결과
docker compose logs -f                  # 실시간 (도커 stdout, 최근 10MB×3)
docker compose logs --tail 100

ls -la /var/log/nano-portal-api/         # 파일 로그 (winston, 일자별 로테이션)
tail -f /var/log/nano-portal-api/$(ls -t /var/log/nano-portal-api | head -1)

curl -s localhost:3001/v1/health                    # liveness (프로세스 살아있음)
curl -s -w " [%{http_code}]\n" localhost:3001/v1/health/ready   # readiness (DB·Redis 확인)
```

컨테이너 헬스체크는 `/v1/health/ready` 를 30초마다 호출한다. DB 나 Redis 가 끊기면
`docker compose ps` 가 unhealthy 로 표시한다(도커가 재시작하지는 않는다 — 사람이 읽는 신호).
503 응답 본문의 `failures` 에 어느 의존성이 왜 실패했는지 들어 있다.

---

## 5. 재시작 / 중지

```bash
cd /opt/nano-portal-api

docker compose restart        # 프로세스만 재기동 (이미지·마운트 그대로)
docker compose up -d          # 변경분만 재생성 (compose.yml·IMAGE_TAG 변경 반영)
docker compose up -d --force-recreate   # 무조건 재생성 (conf 수정 반영은 이쪽)
docker compose down           # 중지 + 컨테이너 제거 (볼륨 데이터는 유지)
docker compose up -d          # 다시 기동
```

`restart: unless-stopped` 라서 서버 재부팅 시 자동 기동한다. 단 `docker compose down` 으로
내린 상태에서는 재부팅해도 올라오지 않는다.

---

## 6. 트러블슈팅

### 컨테이너가 계속 재시작한다

```bash
docker compose logs --tail 100
```

| 로그 증상 | 원인 | 조치 |
|---|---|---|
| `ECONNREFUSED ... 6379` | `REDIS_URL` 이 `localhost` | conf 를 `redis://srt_redis:6379` 로. `localhost` 는 컨테이너 자신 |
| `ER_ACCESS_DENIED` / DB 타임아웃 | DB 자격증명·보안그룹 | conf 의 `DATABASE_*`, RDS 보안그룹에 이 EC2 허용 여부 |
| `EACCES: permission denied, mkdir '/app/logs'` | 볼륨 소유권 | `sudo chown -R 1000:1000 /opt/nano-portal-api /var/log/nano-portal-api` |
| `Cannot find module '@lib/...'` | 이미지 빌드 이상 | 재빌드 필요. tsc-alias 단계 확인 |

### 배포는 성공했는데 접속이 안 된다

```bash
docker compose ps                    # 포트 매핑 0.0.0.0:3001->3001 확인
docker compose exec api node -e "console.log(process.env.SERVICE_PORT)"   # 3001 이어야 함
curl -s localhost:3001/v1/health/ready | head -c 300                        # 의존성 상태
sudo ss -lntp | grep 3001            # 호스트 리슨 확인
```
보안그룹/방화벽에서 3001 이 열려 있는지도 확인한다.

### `network srt_network declared as external, but could not be found`

공유 네트워크가 없다. 호스트 공통 자원이라 배포가 만들지 않는다.
```bash
docker network create srt_network
```

### ECR 로그인 실패 (`no basic auth credentials`)

EC2 인스턴스 프로파일에 ECR 읽기 권한이 없다. `AmazonEC2ContainerRegistryReadOnly` 부착 후:
```bash
aws sts get-caller-identity          # 어떤 역할로 잡히는지 확인
```

### 파이프라인 scp 스텝 실패 (`Permission denied` / `No such file`)

`/opt/nano-portal-api` 가 없거나 배포 SSH 계정 소유가 아니다. 호스트 최초 준비가 안 된 상태:
```bash
sudo bash bootstrap.sh
```

### 디스크가 찬다

```bash
docker system df
docker image prune -f                # 배포 스텝도 매번 수행하지만 수동으로도 가능
du -sh /opt/nano-portal-api/upload /var/log/nano-portal-api
```
업로드는 tmp 승격되지 않은 orphan 을 앱 크론이 정리한다. 로그는 winston 이 일자별 로테이션한다.

---

## 7. 에스컬레이션

- 앱 로직·API 오류 → 앱 개발자
- 배포 파이프라인·호스트·네트워크 → 인프라 담당
- conf 값(시크릿·엔드포인트) 변경 → 앱 개발자와 합의 후 인프라가 반영
