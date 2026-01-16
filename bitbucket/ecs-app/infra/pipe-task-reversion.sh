#!/bin/bash
set -euo pipefail

# =============== 유효성 검사 시작 ===============
# Usage validation
if [ $# -lt 2 ]; then
  echo "❌ Usage: $0 <convert-script-path> <env-file>"
  exit 1
fi

CONVERT_SCRIPT="$1"
ENV_FILE="$2"

# Check existence
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Env file not found: $ENV_FILE"
  exit 1
fi

# ENV JSON 생성
echo "🔧 Converting $ENV_FILE to ECS JSON format..."
ENV_JSON=$($CONVERT_SCRIPT "$ENV_FILE")

# Validate JSON
if ! echo "$ENV_JSON" | jq empty 2>/dev/null; then
  echo "❌ ENV_JSON is not valid JSON"
  exit 1
fi

# =============== 유효성 검사 종료 ===============


# 새로운 이미지
NEW_IMAGE="$AWS_ECR_REPO/$AWS_ECR_NAME:$TARGET_VERSION"
echo "🟢 New image: $NEW_IMAGE"

# 기존 Task Definition + Tags 전체 가져오기
aws ecs describe-task-definition \
  --task-definition "$AWS_TASK_DEFINITION" \
  --include TAGS \
  --output json > full_task_def.json

# 태그 추출
jq '.tags' full_task_def.json > tags.json
# Task Definition만 추출
jq '.taskDefinition' full_task_def.json > current_task_def.json

# Task Definition 업데이트 (이미지 + ENV 반영)
jq --arg IMAGE "$NEW_IMAGE" \
   --argjson ENV_JSON "$ENV_JSON" '
   .containerDefinitions[0].image = $IMAGE |
   .containerDefinitions[0].environment = $ENV_JSON |
   del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
       .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
   ' current_task_def.json > updated_task_def.json

# Preview
echo "🟢 Updated Task Definition (preview):"
jq '.containerDefinitions[0] | {image, environment}' updated_task_def.json

# 새 Task Definition 등록
NEW_REVISION=$(aws ecs register-task-definition \
  --cli-input-json file://updated_task_def.json \
  --tags file://tags.json \
  --query 'taskDefinition.revision' \
  --output text)

echo "✅ Task Definition updated with image=$NEW_IMAGE (revision=$NEW_REVISION)"
export NEW_REVISION
