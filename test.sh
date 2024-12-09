#!/bin/bash

# Variables (사용자 정의 필요)
CLUSTER_NAME="your-cluster-name"  # ECS 클러스터 이름
SERVICE_NAME="your-service-name"  # ECS 서비스 이름
ASG_NAME="your-asg-name"          # Auto Scaling Group 이름
NEW_COOLDOWN=300                  # Cooldown 시간 (초)
LOG_FILE="script_execution.log"   # 실행 로그 파일

# Error handling
set -euo pipefail

# Log 시작
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== 스크립트 실행 시작 ==="
echo "로그 파일: $LOG_FILE"

# Step 1: Check Managed Termination Protection 상태
echo "[1] Managed Termination Protection 상태 확인 중..."
MTP_STATUS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" \
  --query 'services[].deploymentConfiguration.managedTerminationProtection' --output text)

if [ "$MTP_STATUS" == "ENABLED" ]; then
  echo "  - Managed Termination Protection이 활성화되어 있습니다."
else
  echo "  - Managed Termination Protection이 비활성화되어 있습니다."
fi

# Step 2: Managed Termination Protection 비활성화
echo "[2] Managed Termination Protection 비활성화 중..."
aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" \
  --deployment-configuration deploymentCircuitBreaker="{enable=false,rollback=false},maximumPercent=200,minimumHealthyPercent=50"
echo "  - Managed Termination Protection 비활성화 완료."

# Step 3: ECS 클러스터에서 실행 중인 태스크 확인
echo "[3] ECS 클러스터에서 실행 중인 태스크 확인 중..."
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns[0]' --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
  echo "  - 실행 중인 태스크가 없습니다."
  exit 0
fi
echo "  - 실행 중인 태스크 ARN: $TASK_ARN"

# Step 4: 특정 ECS 태스크 중지
echo "[4] ECS 태스크 중지 중..."
aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$TASK_ARN"
echo "  - 태스크 중지 완료."

# Step 5: Auto Scaling Group 설정 확인
echo "[5] Auto Scaling Group 설정 확인 중..."
ASG_INFO=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity,DefaultCooldown]' --output table)
echo "$ASG_INFO"

# Step 6: Auto Scaling Group Cooldown 시간 수정
echo "[6] Auto Scaling Group Cooldown 시간 수정 중..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" \
  --default-cooldown "$NEW_COOLDOWN"
echo "  - Cooldown 시간 $NEW_COOLDOWN초로 설정 완료."

# Step 7: Capacity Provider 설정 확인
echo "[7] Capacity Provider 설정 확인 중..."
CAPACITY_INFO=$(aws ecs describe-capacity-providers --query 'capacityProviders[].{Name: name, ManagedScaling: managedScaling, TerminationProtection: managedTerminationProtection}' \
  --output table)
echo "$CAPACITY_INFO"

# Step 8: CloudTrail 로그 확인
echo "[8] CloudTrail 로그 확인 중..."
CLOUDTRAIL_EVENTS=$(aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventSource,AttributeValue=autoscaling.amazonaws.com \
  --query 'Events[].{EventTime: EventTime, EventName: EventName, Resource: Resources[0].ResourceName}' --output table || echo "  - CloudTrail 로그 조회 실패")
echo "$CLOUDTRAIL_EVENTS"

echo "=== 스크립트 실행 완료 ==="
