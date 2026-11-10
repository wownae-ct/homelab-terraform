# homelab-terraform

홈랩 하이브리드 플랫폼(Proxmox 위 Kubernetes + AWS + Cloudflare)을 코드로 정의한 Terraform입니다.
Proxmox, AWS, Cloudflare 세 프로바이더를 한 코드에서 관리합니다.

> 공개용으로 정리한 저장소입니다. 계정 ID, 관리자 IP, 키, 웹훅 URL 같은 값은 코드에 없고 변수와 환경 변수로 받습니다.

## 만드는 것

| 영역 | 리소스 |
|---|---|
| Proxmox (`modules/proxmox`) | Kubernetes VM 6대(Master 3, Worker 3). 템플릿 VM을 풀 클론하고 cloud-init으로 IP와 SSH 키를 넣습니다. Worker에는 Longhorn용 디스크를 추가합니다. |
| AWS (`modules/aws`) | ECR 저장소 3개, 외부 진입용 NAT EC2(t3.micro) + Elastic IP + 보안 그룹(80/443, WireGuard 51820/udp, SSH는 관리자 IP만), SNS 토픽(이메일 구독), DynamoDB(TTL), Lambda 2개, EventBridge 스케줄 |
| Cloudflare (`modules/cloudflare`) | R2 버킷(Terraform state와 백업 저장) |

## 알림 흐름 (SNS + Lambda + DynamoDB + EventBridge)

```
Alertmanager → SNS → Lambda(alert_collector)
                        ├─ critical / resolved → 즉시 Discord
                        └─ 그 외(warning 등) → DynamoDB (TTL 24시간)
EventBridge(매일 KST 09:00) → Lambda(alert_batch_sender) → 쌓인 알림을 요약해 Discord
```

critical은 바로 보내고 warning은 모아서 하루 한 번 요약해 보내, 알림이 쌓여 중요한 것이 묻히는 것을 줄입니다.

## 사용법

1. 변수 파일을 만듭니다.
   ```bash
   cp terraform.tfvars.example terraform.tfvars   # 값 채우기
   cp backend.hcl.example backend.hcl             # R2 endpoint / access key 채우기
   ```
2. 자격 증명은 환경 변수나 프로필로 전달합니다.
   - AWS: `aws configure`
   - Cloudflare: `export CLOUDFLARE_API_TOKEN=...`
   - Proxmox: `export PROXMOX_VE_API_TOKEN=...`
3. Lambda 배포 파일을 만들고 적용합니다.
   ```bash
   ./scripts/build_lambda.sh
   terraform init -backend-config=backend.hcl
   terraform plan
   terraform apply
   ```

## 구성

```
.
├── main.tf / variables.tf / outputs.tf / versions.tf / backend.tf
├── modules/
│   ├── proxmox/      # VM 6대
│   ├── aws/          # ECR, NAT EC2, SNS, DynamoDB, Lambda, EventBridge
│   │   └── lambda/   # alert_collector.py, alert_batch_sender.py
│   └── cloudflare/   # R2 버킷
└── scripts/build_lambda.sh
```

## 알려진 한계

- Terraform state는 Cloudflare R2(S3 호환)에 둡니다. R2에는 DynamoDB 같은 네이티브 state lock이 없습니다. 1인 운영이라 감수했고, 여러 명이 쓰려면 별도 락이 필요합니다.
- Proxmox 프로바이더는 자체 서명 인증서 환경이라 `insecure = true`로 설정했습니다.
- Kubernetes 설치와 서버 설정(Ansible)은 [infra-repo/ansible](https://github.com/wownae-ct/infra-repo/tree/master/ansible)에, GitOps 매니페스트는 [infra-repo/apps](https://github.com/wownae-ct/infra-repo/tree/master/apps)에 있습니다. 이 저장소에는 두 가지가 없습니다.
