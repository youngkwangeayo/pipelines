# infra — 배포 대상 호스트 구성

배포에 필요한 호스트 구성을 레포에서 관리한다. 파이프라인(`bitbucket-pipelines.yml`)의
배포 스텝이 이 디렉토리 내용을 `/opt/nano-portal-api/` 로 복사한 뒤 `docker compose up -d` 를 실행한다.
`bootstrap.sh` 도 함께 올라가지만 실행은 호스트당 1회 수동이다.

| 파일 | 역할 |
|---|---|
| `compose.yml` | 컨테이너 실행 정의 (포트·볼륨·네트워크·보안 옵션). 매 배포 갱신 |
| `bootstrap.sh` | 디렉토리 생성 + 소유권(uid 1000) + 홈 심볼릭. **호스트당 1회 사람이 수동 실행** |
| `RUNBOOK.md` | 배포·롤백·설정변경·장애대응 절차 (UI / 서버 수동) |
| `HOST-ISSUES.md` | dev-srt 호스트에서 확인된 문제 (디스크·S3 마운트). 인프라 담당자 전달용 |

## 호스트 레이아웃

```
/opt/nano-portal-api/                ← 전체가 uid 1000 소유 (bootstrap.sh)
  compose.yml                        ← 파이프라인이 갱신
  bootstrap.sh                       ← 파이프라인이 갱신 (실행은 수동 1회)
  .env                               ← 파이프라인이 생성 (compose 변수: IMAGE_TAG 등)
  config/nano-portal-api.conf        ← 시크릿. 최초 1회 사람이 배치 (레포에 없음)
  upload/                            ← 업로드 볼륨

/var/log/nano-portal-api/            ← 로그 볼륨 (uid 1000)
~/nano-portal-api                    ← /opt/nano-portal-api 심볼릭 (bootstrap.sh, 로그인 사용자 홈)
```

## 새 환경 구축 (환경당 1회)

DEV/PROD 같은 환경을 새로 올릴 때의 순서. 파이프라인은 **배포만** 하므로 아래는 사람이 한 번 해둬야 한다.
빠뜨리면 배포는 성공했는데 접속이 안 되거나, 설정 없이 컨테이너만 뜬다.

### 1. Bitbucket

- **Settings > Deployments** 에 환경 생성 (`development` / `production`)
- 각 환경에 변수 `DEPLOY_SSH_HOST` = 해당 EC2 주소
- 레포지토리 변수: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`,
  `AWS_ECR_REPO`, `AWS_ECR_NAME`, `DEPLOY_SSH_USER`
- **Settings > SSH keys** — 키 생성 후 공개키를 대상 서버 `~/.ssh/authorized_keys` 에 등록,
  **Known hosts** 에 대상 호스트 추가 (이게 없으면 scp/ssh 스텝이 호스트 검증에서 멈춘다)

### 2. AWS

- **ECR 리포지토리** — 없으면 `aws-ecr-push-image` 파이프가 첫 배포 때 자동 생성한다
- **EC2 인스턴스 프로파일** — ECR 읽기 권한(`AmazonEC2ContainerRegistryReadOnly`).
  배포 스크립트가 서버에서 `aws ecr get-login-password` 를 호출한다
- **타겟그룹** — 대상 포트 **3001**, 프로토콜 HTTP,
  헬스체크 경로 **`/v1/health/ready`** (DB·Redis 까지 확인하므로 의존성이 끊긴 인스턴스를 자동으로 뺀다.
  단순 생존 확인만 원하면 `/v1/health`)
- **ALB 리스너 룰** — 호스트 헤더(예: `portal-api-dev.coffeezip.net`) → 위 타겟그룹
- **보안그룹** — ALB → EC2 의 3001 인바운드 허용
- **DNS** — 도메인을 ALB 로 향하게

### 3. 호스트

```bash
# 1) 디렉토리 생성 + 소유권 + ~/nano-portal-api 심볼릭
#    (레포를 클론했거나 bootstrap.sh 만 서버로 복사해 실행)
sudo bash bootstrap.sh

# 2) 시크릿 conf 배치 — 이 파일이 없는 채로 배포하면 docker 가 같은 이름의 빈 디렉토리를 만들어
#    마운트해버린다. 그러면 설정이 0개 로드된 채 컨테이너만 뜬다. 반드시 배포 전에.
sudo cp <앱 개발자에게 전달받은 conf> /opt/nano-portal-api/config/nano-portal-api.conf
sudo chown 1000:1000 /opt/nano-portal-api/config/nano-portal-api.conf
sudo chmod 600 /opt/nano-portal-api/config/nano-portal-api.conf

# 3) 공유 네트워크가 없다면 (호스트 공통 자원이라 배포가 만들지 않는다)
docker network inspect srt_network || docker network create srt_network

# 4) 포트 충돌 확인 — 이 호스트는 여러 앱이 공유한다
sudo ss -lntp | grep 3001 || echo "3001 사용 가능"
```

배포 SSH 계정이 `/opt/nano-portal-api` 에 쓸 수 있어야 한다
(EC2 기본 계정 `ubuntu`/`ec2-user` 가 uid 1000 이라 위 chown 과 일치한다. 다른 계정으로 배포한다면
그 계정을 gid 1000 그룹에 넣거나 소유권을 맞출 것).

### 4. 첫 배포와 검증

```bash
git tag 0.1.0 && git push origin 0.1.0        # 파이프라인 → 빌드 → DEV 자동 (PROD 는 UI 에서 Run)

# 서버에서
cd /opt/nano-portal-api
docker compose ps                              # healthy
docker compose logs | grep "injected env"      # (0) 이면 conf 가 안 붙은 것
curl -s -w " [%{http_code}]\n" localhost:3001/v1/health/ready

# 밖에서 (ALB 경유)
curl -s -w " [%{http_code}]\n" https://<도메인>/v1/health
curl -s https://<도메인>/docs                   # Swagger. info.version 이 배포 태그와 같은지 확인
```

conf 형식은 레포의 `.env.template` 참고. 아래 값은 반드시 맞춘다:

- `SERVICE_PORT` — 컨테이너 배포에서는 **무시된다.** 앱 개발자의 로컬 실행용 값이고,
  이미지 ENV(3001)가 이미 설정돼 있어 dotenv 가 덮어쓰지 않는다(override 기본 false).
  conf 는 `/app/.env` 로 마운트된다.
  포트를 바꾸려면 `Dockerfile` 의 `ENV`/`EXPOSE` 와 `compose.yml` 의 `ports`·헬스체크를 함께 바꾼다.
- `REDIS_URL=redis://srt_redis:6379` — `localhost` 는 컨테이너 자신을 가리켜 연결이 실패한다.
- `PUBLIC_BASE_URL` — 다운로드 URL 생성에 쓰이므로 외부에서 실제로 접근하는 주소.

## 보류 중인 요건

- **업로드 저장소를 S3 마운트(`/mnt/<버킷>/data/nano-portal-api/upload`)로 이전** — 경로·마운트 방식이
  확정되지 않아 미적용. `bootstrap.sh` 하단에 주석으로 준비해 뒀다.
  그냥 얹으면 저장 계층의 `fs.rename()`(tmp→files 승격)에서 깨지므로 선행 검토가 필요하다.

시크릿을 SSM Parameter Store / Secrets Manager 로 옮기는 건 다음 단계. 그때는 이 수동 배치가
배포 스텝의 파라미터 조회로 대체된다.

## 운영

```bash
cd /opt/nano-portal-api
docker compose ps
docker compose logs -f
docker compose restart
```

`.env` 가 있어 변수 지정 없이 그대로 동작한다. 롤백 절차는 [RUNBOOK.md](./RUNBOOK.md) 참고.
