#!/bin/bash

# Variables (사용자 정의 필요)
CLUSTER_NAME="your-cluster-name" # ECS 클러스터 이름
SERVICE_NAME="your-service-name" # ECS 서비스 이름
ASG_NAME="your-asg-name"         # Auto Scaling Group 이름
NEW_COOLDOWN=${NEW_COOLDOWN:-300} # Cooldown 시간 (초), 기본값 300

# Error handling
set -euo pipefail

# Step 1: Check Managed Termination Protection 설정 상태
echo "ECS 서비스의 Managed Termination Protection 상태 확인 중..."
MTP_STATUS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" \
  --query 'services[].deploymentConfiguration.managedTerminationProtection' \
  --output text)

if [ "$MTP_STATUS" == "ENABLED" ]; then
  echo "Managed Termination Protection이 활성화되어 있습니다."
else
  echo "Managed Termination Protection이 비활성화되어 있습니다."
fi

# Step 2: Managed Termination Protection 비활성화
echo "Managed Termination Protection을 비활성화합니다..."
aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" \
  --deployment-configuration deploymentCircuitBreaker="{enable=false,rollback=false},maximumPercent=200,minimumHealthyPercent=50"
echo "Managed Termination Protection 비활성화 완료."

# Step 3: ECS 클러스터에서 실행 중인 태스크 확인
echo "ECS 클러스터에서 실행 중인 태스크 목록을 확인합니다..."
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns[0]' --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
  echo "실행 중인 태스크가 없습니다."
  exit 0
fi

echo "태스크 ARN: $TASK_ARN"

# Step 4: 특정 ECS 태스크 중지
echo "태스크 $TASK_ARN 중지 중..."
aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$TASK_ARN" || {
  echo "태스크 중지 중 오류가 발생했습니다."
  exit 1
}
echo "태스크 중지 완료."

# Step 5: Auto Scaling Group 설정 확인
echo "Auto Scaling Group 설정 확인 중..."
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity,DefaultCooldown]' \
  --output table || {
  echo "Auto Scaling Group 설정을 가져오는 데 실패했습니다."
  exit 1
}

# Step 6: ASG Cooldown 설정 수정
echo "Auto Scaling Group의 Cooldown 시간을 $NEW_COOLDOWN초로 수정합니다..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" \
  --default-cooldown "$NEW_COOLDOWN" || {
  echo "Cooldown 시간 수정 중 오류가 발생했습니다."
  exit 1
}
echo "Cooldown 시간 수정 완료."

# Step 7: Capacity Provider 설정 확인
echo "Capacity Provider 설정 확인 중..."
aws ecs describe-capacity-providers --query 'capacityProviders[].{Name: name, ManagedScaling: managedScaling, TerminationProtection: managedTerminationProtection}' \
  --output table || {
  echo "Capacity Provider 설정을 가져오는 데 실패했습니다."
  exit 1
}

# Step 8: CloudTrail 로그에서 Scale-In 이벤트 확인
echo "CloudTrail 로그에서 Auto Scaling 관련 이벤트를 확인합니다..."
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventSource,AttributeValue=autoscaling.amazonaws.com \
  --query 'Events[].{EventTime: EventTime, EventName: EventName, Resource: Resources[0].ResourceName}' \
  --output table || {
  echo "CloudTrail 로그를 가져오는 데 실패했습니다."
  exit 1
}

echo "스크립트 실행 완료. 위 결과를 검토하세요."
