#!/usr/bin/env bash
# 호스트 최초 준비 — 사람이 서버에서 1회만 실행한다 (배포 파이프라인은 실행하지 않는다).
#
#   sudo bash bootstrap.sh
#
# 하는 일
#   1) 앱 디렉토리(upload/config)와 로그 디렉토리(/var/log/<앱>) 생성 + 소유권을 uid 1000(node)로 변경
#   2) ~/<앱> → /opt/<앱> 심볼릭 (로그인 사용자 홈에서 바로 접근)
# git 은 디렉토리 소유권·퍼미션을 저장하지 못하므로 이 부분만 스크립트가 담당한다.
# 여러 번 실행해도 결과가 같다(멱등). 기존 파일을 지우거나 덮어쓰지 않는다.
set -euo pipefail

APP_NAME=nano-portal-api
APP_DIR=/opt/${APP_NAME}
LOG_DIR=/var/log/${APP_NAME}   # 로그는 호스트 관례대로 /var/log 아래 (다른 앱과 동일)
APP_UID=1000   # 이미지의 node 유저. Dockerfile 의 USER 를 바꾸면 여기도 함께 바꿀 것

# sudo 로 실행되므로 $HOME 은 root 의 것이다 → 실제 로그인 사용자의 홈을 찾는다
LOGIN_USER=${SUDO_USER:-$(id -un)}
LOGIN_HOME=$(getent passwd "${LOGIN_USER}" | cut -d: -f6)
HOME_LINK=${LOGIN_HOME}/${APP_NAME}

mkdir -p "${APP_DIR}"/upload "${APP_DIR}"/config "${LOG_DIR}"
chown -R ${APP_UID}:${APP_UID} "${APP_DIR}" "${LOG_DIR}"

# 실제 경로는 /opt 에 두고 로그인 사용자 홈에서 심볼릭으로 접근한다 (cd ~/nano-portal-api).
# -n: 링크가 이미 있으면 그 안으로 들어가지 않고 링크 자체를 교체 (중첩 링크 방지)
# 같은 이름의 실제 디렉토리가 있으면 건드리지 않고 넘어간다.
if [ -d "${HOME_LINK}" ] && [ ! -L "${HOME_LINK}" ]; then
  echo "경고: ${HOME_LINK} 가 실제 디렉토리다. 심볼릭을 만들지 않고 건너뛴다."
else
  ln -sfn "${APP_DIR}" "${HOME_LINK}"
  chown -h "${LOGIN_USER}":"${LOGIN_USER}" "${HOME_LINK}"
fi

# ── [미적용] 업로드를 S3 마운트로 옮기는 경우 ────────────────────────────────
# 요건: /mnt/<버킷마운트>/data/${APP_NAME}/upload 를 업로드 저장소로 사용.
# 실제 마운트 경로·방식(mountpoint-s3 / s3fs)이 확정되면 아래를 열고 compose 의
# 업로드 볼륨을 그 경로로 바꾼다.
#
#   S3_UPLOAD_DIR=/mnt/srt_bucket/data/${APP_NAME}/upload
#   mkdir -p "${S3_UPLOAD_DIR}"
#   chown ${APP_UID}:${APP_UID} "${S3_UPLOAD_DIR}"   # FUSE 는 마운트 옵션(uid=)으로 정해지는 경우가 많다
#
# 선행 확인 사항 (그냥 얹으면 업로드 기능이 깨진다):
#   · 저장 계층이 tmp→files 승격에 fs.rename() 을 쓴다 (src/lib/storage/index.ts:54).
#     mountpoint-s3 는 rename 미지원이라 승격이 실패하고, s3fs 는 서버사이드 copy+delete 로
#     동작해 1GB 파일마다 전체 복사가 일어난다 (MAX_UPLOAD_MB 기본 1024).
#   · 업로드 직후 sha256 계산을 위해 파일을 다시 읽는다 → 매 업로드마다 오브젝트 재다운로드.
#   · FUSE 를 컨테이너에 bind mount 하려면 마운트가 컨테이너 기동 전에 존재해야 하고,
#     allow_other 로 마운트해야 하며, 재마운트 시 컨테이너는 stale handle 이 된다.
#   → 권장: 로컬 볼륨 유지 + 야간 aws s3 sync, 또는 저장 계층을 S3 SDK 로 교체.
# ──────────────────────────────────────────────────────────────────────────

cat <<MSG
준비 완료
  ${APP_DIR}       (upload, config / uid ${APP_UID})
  ${LOG_DIR}       (로그 / uid ${APP_UID})
  ${HOME_LINK} -> ${APP_DIR}   (cd ~/${APP_NAME})

이어서 할 일:
  1) 런타임 설정(시크릿) 배치 — 레포에 없으므로 사람이 직접 넣는다
       sudo cp <전달받은 conf> ${APP_DIR}/config/${APP_NAME}.conf
       sudo chown ${APP_UID}:${APP_UID} ${APP_DIR}/config/${APP_NAME}.conf
       sudo chmod 600 ${APP_DIR}/config/${APP_NAME}.conf
     ※ SERVICE_PORT 는 로컬 실행용 값이라 배포에선 무시된다 (이미지 ENV=3001 우선)
     ※ REDIS_URL 은 redis://srt_redis:6379 — localhost 는 컨테이너 자신을 가리킨다

  2) 공유 네트워크 확인 (호스트 공통 자원이라 배포가 만들지 않는다)
       docker network inspect srt_network || docker network create srt_network

  3) 이후 배포는 태그 push 로 파이프라인이 수행한다 (compose.yml 전송 → docker compose up -d)
MSG
