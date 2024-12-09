# ECS Auto Scaling 관리 스크립트

이 스크립트는 AWS ECS 및 Auto Scaling Group의 설정을 관리하고 상태를 확인하는 데 사용됩니다. 주요 기능으로는 Managed Termination Protection 비활성화, ECS 태스크 관리, Auto Scaling Group 설정 변경 등이 포함됩니다.

---

## 📋 주요 기능

1. **Managed Termination Protection 상태 확인 및 비활성화**
   - ECS 서비스의 Managed Termination Protection 상태를 확인하고 비활성화합니다.

2. **ECS 태스크 관리**
   - 실행 중인 ECS 태스크를 확인하고 중지합니다.

3. **Auto Scaling Group 관리**
   - Auto Scaling Group의 설정(예: Cooldown 시간)을 확인하고 변경합니다.

4. **Capacity Provider 상태 확인**
   - Capacity Provider의 Managed Scaling 및 Termination Protection 설정 상태를 확인합니다.

5. **CloudTrail 로그 확인**
   - Auto Scaling 관련 이벤트를 CloudTrail 로그에서 검색합니다.

---

## 📦 요구 사항

### **필수 환경**
- **AWS CLI 설치 및 설정**: AWS CLI가 설치되고, 올바른 권한의 프로필이 설정되어 있어야 합니다.
- **Bash 쉘**: 스크립트는 Bash 쉘에서 실행됩니다.
- **IAM 권한**: 아래 권한이 필요합니다.
  - `ecs:DescribeServices`
  - `ecs:UpdateService`
  - `ecs:ListTasks`
  - `ecs:StopTask`
  - `autoscaling:DescribeAutoScalingGroups`
  - `autoscaling:UpdateAutoScalingGroup`
  - `ecs:DescribeCapacityProviders`
  - `cloudtrail:LookupEvents`

### **스크립트 변수**
- `CLUSTER_NAME`: ECS 클러스터 이름
- `SERVICE_NAME`: ECS 서비스 이름
- `ASG_NAME`: Auto Scaling Group 이름
- `NEW_COOLDOWN`: Auto Scaling Group의 새로운 Cooldown 시간(초)

---

## 🛠️ 사용법

### 1. **스크립트 실행 준비**
- 스크립트를 로컬에 다운로드하거나 복사합니다.
- 실행 권한 부여:
  ```bash
  chmod +x script.sh
