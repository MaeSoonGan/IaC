# Terraform AWS 인프라 구성 설명서

## 개요

AWS 클라우드 인프라를 Terraform으로 구성하는 코드입니다.
VPC, EKS, RDS, ElastiCache, ALB/NLB, WAF, S3, Bastion 등 전체 인프라를 모듈 단위로 관리합니다.

---

## 디렉토리 구조

```
Terraform/
├── network/                  # VPC, 서브넷, IGW, NAT GW, Route Table
│   ├── vpc.tf
│   ├── subnet.tf
│   ├── internet_gateway.tf
│   ├── nat_gateway.tf
│   ├── route_table.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── security_group/           # Security Groups
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── kubernetes_cluster/       # EKS 클러스터, 노드 그룹, Add-ons, OIDC
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── database/                 # RDS MariaDB (Primary + Replica)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── cache/                    # ElastiCache Redis (Primary + Replica)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── load_balancer/            # NLB, ALB, WAF, S3, Route53
│   ├── nlb.tf
│   ├── alb.tf
│   ├── waf.tf
│   ├── s3.tf
│   ├── route53.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── bastion_host/             # Bastion EC2
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── main.tf                   # 루트 모듈 - 전체 모듈 호출
├── variables.tf              # 공통 변수
├── provider.tf               # AWS / TLS 프로바이더
├── terraform.tfvars          # 변수 실제 값 (git 제외)
├── .gitignore
└── README.md
```

---

## 사전 요구사항

- Terraform >= 1.5.0
- AWS CLI 설정 완료
- 리전: `ap-northeast-2` (서울)

---

## 변수 설정

### `variables.tf`

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `prefix` | `maesoongan` | 모든 리소스명 앞에 붙는 prefix |
| `db_password` | 없음 | RDS 마스터 비밀번호 |
| `redis_password` | 없음 | Redis 인증 토큰 |
| `domain_name` | 없음 | Route53 도메인명 |

### `terraform.tfvars`

민감 정보를 저장하는 파일입니다. git에 올라가지 않습니다.

```hcl
prefix         = "maesoongan"
db_password    = "변경 필요"
redis_password = "변경 필요"
domain_name    = "도메인명"
```

---

## 실행 방법

### 최초 배포

```bash
# 1. 초기화
terraform init

# 2. 계획 확인
terraform plan

# 3. 배포
terraform apply
```

### 모듈 구조 변경 후 재배포 (state 이동 필요 시)

```bash
terraform init

terraform state mv module.vpc module.network
terraform state mv module.sg module.security_group
terraform state mv module.eks module.kubernetes_cluster
terraform state mv module.rds module.database
terraform state mv module.redis module.cache
terraform state mv module.s3 module.load_balancer
terraform state mv module.bastion module.bastion_host

terraform apply
```

### 리소스 삭제

```bash
terraform destroy
```

---

## 리소스 구성

### VPC / 네트워크

| 리소스 | CIDR |
|--------|------|
| VPC | `10.14.0.0/16` |
| Public Subnet A (ap-northeast-2a) | `10.14.10.0/24` |
| Public Subnet C (ap-northeast-2c) | `10.14.20.0/24` |
| EKS Subnet A | `10.14.110.0/24` |
| EKS Subnet C | `10.14.120.0/24` |
| DB Subnet A | `10.14.210.0/24` |
| DB Subnet C | `10.14.220.0/24` |
| Redis Subnet A | `10.14.230.0/24` |
| Redis Subnet C | `10.14.240.0/24` |

- NAT Gateway: AZ별 2개 (고가용성)
- Route Table: Public 1개, Private 2개 (AZ별)

---

### Security Groups

| 이름 | 허용 규칙 |
|------|----------|
| `alb-sg` | 80, 443 전체 허용 |
| `eks-node-sg` | ALB 전체, 노드 간 통신, 온프레미스 3곳(443), VPC 내부(443) |
| `bastion-sg` | SSH 22 전체 허용 |
| `rds-sg` | EKS 노드, Bastion → 3306 |
| `cache-sg` | EKS 노드 → 6379 |

---

### EKS

| 항목 | 값 |
|------|-----|
| 버전 | 1.35 |
| 엔드포인트 | Public + Private |
| 로그 | api, audit, authenticator |

**Node Groups**

| 이름 | 역할 | 노드 수 | 이중화 |
|------|------|---------|-------|
| `nodegroup-frontend` | 사용자/관리자 Pod | 2 | ✓ |
| `nodegroup-service` | 서비스 Pod | 2 | ✓ |
| `nodegroup-realtime` | 실시간 시세 전송 Pod 전용 | 2 | ✓ |
| `nodegroup-async` | 비동기 작업 Pod | 1 | ✗ |
| `nodegroup-cicd` | CI/CD Pod | 1 | ✗ |

- 인스턴스: `t3.medium`
- OS: Amazon Linux 2023

**Add-ons**
- VPC CNI, CoreDNS, kube-proxy 자동 설치

**OIDC Provider**
- Load Balancer Controller 등 IAM 연동용

---

### RDS (MariaDB)

| 항목 | 값 |
|------|-----|
| 엔진 | MariaDB 11.4 |
| 인스턴스 | `db.t3.micro` |
| 스토리지 | 20GB / 암호화 |
| DB명 | `fisaschool` |
| 구성 | Primary(2a) + Replica(2c) |
| max_connections | 300 |

---

### ElastiCache (Redis)

| 항목 | 값 |
|------|-----|
| 엔진 | Redis 7.1 |
| 인스턴스 | `cache.t3.micro` |
| 구성 | Primary(2a) + Replica(2c) / Multi-AZ |
| 암호화 | 저장 + 전송 |
| 인증 | auth_token 사용 |

---

### NLB / ALB / WAF / S3

| 항목 | 값 |
|------|-----|
| NLB | 외부 공개 / 포트 80 |
| ALB | 내부(internal) / 포트 80 |
| HTTP 리스너 | EKS Target Group으로 포워딩 |
| HTTPS 리스너 | 비활성화 (ACM 인증서 확보 후 활성화) |
| WAF | AWSManagedRulesCommonRuleSet 외 1개 |
| S3 | 암호화(AES256), 버전 관리 |

**트래픽 흐름**
```
인터넷 → NLB(80) → ALB(80) → EKS 노드
```

---

### Route53

- 기존 Hosted Zone 참조 (콘솔에서 생성된 것 사용)
- `{domain}` 및 `www.{domain}` A 레코드 → NLB

---

### Bastion Host

| 항목 | 값 |
|------|-----|
| 인스턴스 | `t3.micro` |
| OS | Amazon Linux 2023 |
| 위치 | Public Subnet A |

**SSH 접속 방법**
```bash
# Private Key 추출
terraform output -raw module.bastion_host.bastion_private_key > bastion.pem
chmod 400 bastion.pem

# 접속
ssh -i bastion.pem ec2-user@$(terraform output -raw module.bastion_host.bastion_public_ip)
```

---

## Apply 후 작업

### 필수

```bash
# kubeconfig 연결
aws eks update-kubeconfig --region ap-northeast-2 --name {prefix}-cluster
```

| 작업 | 방법 |
|------|------|
| AWS Load Balancer Controller 설치 | helm |
| 팀원 EKS 접근 권한 추가 | 콘솔 → EKS → Access 탭 |
| Customer Gateway / VPN 설정 | 콘솔 (pfSense 연동) |

### 나중에

| 작업 | 조건 |
|------|------|
| HTTPS 활성화 | ACM 인증서 발급 후 `alb.tf`, `variables.tf` 주석 해제 |
| K8s Pod 배포 | 개발팀 별도 yaml 작성 |

---

## 주의사항

- `terraform.tfvars` : git에 절대 올리지 않기 (.gitignore 적용됨)
- `terraform.tfstate` : git에 올리지 않기 (.gitignore 적용됨)
- NAT Gateway 2개 운영으로 비용 발생
- Bastion Private Key는 `terraform output`으로만 확인 가능
