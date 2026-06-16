# AWS 인프라 구성 설명서

> **프로젝트**: 한국투자증권 OpenAPI 기반 모의투자 서비스 — 채널계 인프라<br>
> **리전**: `ap-northeast-2` (서울)<br>
> **Terraform**: `>= 1.5.0` / **AWS Provider**: `~> 5.0`

<br>

---

## 목차

1. [서비스 개요 및 아키텍처 설계 철학](#1-서비스-개요-및-아키텍처-설계-철학)
2. [전체 트래픽 흐름](#2-전체-트래픽-흐름)
3. [디렉토리 구조](#3-디렉토리-구조)
4. [모듈별 상세 설명](#4-모듈별-상세-설명)
   - [Network](#41-network)
   - [Security Group](#42-security-group)
   - [EKS (Kubernetes Cluster)](#43-eks-kubernetes-cluster)
   - [Database](#44-database)
   - [Cache](#45-cache)
   - [Load Balancer](#46-load-balancer)
   - [Bastion Host](#47-bastion-host)
5. [IAM 설계](#5-iam-설계)
6. [변수 설정](#6-변수-설정)
7. [실행 방법](#7-실행-방법)
8. [Apply 후 필수 작업](#8-apply-후-필수-작업)
9. [이중화 적용 체크리스트](#9-이중화-적용-체크리스트)
10. [주의사항](#10-주의사항)

<br>

---

## 1. 서비스 개요 및 아키텍처 설계 철학

### 서비스 소개

한국투자증권 OpenAPI를 연동한 **모의투자 플랫폼**으로, 실제 주식 시장 데이터를 기반으로 가상 자산으로 투자를 연습할 수 있는 서비스입니다.

<br>

### 채널계 / 계정계 분리 구조

금융권 표준 아키텍처인 **채널계 / 계정계 분리 구조**를 채택했습니다.

| 구분               | 위치                          | 역할                                        |
| ------------------ | ----------------------------- | ------------------------------------------- |
| **채널계**   | AWS (ap-northeast-2)          | 사용자 UI, API, 실시간 시세, 비동기 처리    |
| **계정계**   | On-Premises (메인 데이터센터) | 계정 원장, 주문 체결 엔진, Kafka, Master DB |
| **DR**       | On-Premises (DR 데이터센터)   | 계정계 이중화, Slave DB, Kafka 복제         |
| **모니터링** | On-Premises (Monitoring 서버) | Prometheus, Grafana, Loki, AlertManager     |

<br>

### 채널계를 AWS에 구축한 이유

- **탄력적 확장**: 주식 시장 개장(09:00) 직후와 마감(15:30) 직전에 트래픽이 급증합니다. EKS Auto Scaling으로 자동 대응합니다.
- **Stateless 워크로드 최적화**: 채널계 서비스는 상태를 갖지 않아 컨테이너화에 적합합니다.
- **관리형 서비스 활용**: RDS, ElastiCache 등 AWS 관리형 서비스로 운영 부담을 줄입니다.

<br>

### 계정계를 On-Premises에 유지하는 이유

- **초저지연 요구사항**: 주문 체결 엔진은 마이크로초 단위 처리가 필요합니다.
- **금융 데이터 보안**: 계정 원장, 체결 내역 등 핵심 금융 데이터는 자체 데이터센터에서 엄격히 관리합니다.

<br>

### AWS ↔ On-Premises 연결

Site-to-Site VPN을 통해 암호화된 전용 터널로 채널계(AWS)와 계정계(On-Premises)가 통신합니다.

<br>

---

## 2. 전체 트래픽 흐름

```
[사용자]
   │
   ▼
[Route53] ── DNS A 레코드 → NLB
   │
   ▼
[NLB] ── Public Subnet A/C, 포트 80 TCP
   │      정적 IP 제공, L4 레벨 고성능 처리
   ▼
[WAF] ── SQL Injection, XSS, 악성 입력 차단
   │
   ▼
[ALB] ── Internal, Public Subnet A/C, 포트 80 HTTP
   │      L7 경로/호스트 기반 라우팅
   ▼
[EKS 워커 노드] ── Private Subnet A/C
   ├── [RDS MariaDB] ── DB Subnet A(Primary) / C(Replica)
   └── [ElastiCache Redis] ── Redis Subnet A(Primary) / C(Replica)

[관리자]
   │
   ▼
[Session Manager] ── SSH 포트 없이 AWS 콘솔 접속
   │
   ▼
[Bastion Host] ── Public Subnet A
   ├── kubectl → EKS API 서버 (Private Endpoint)
   └── MySQL 클라이언트 → RDS (3306)

[On-Premises ↔ AWS]
   └── Site-to-Site VPN (암호화 터널)
         ├── 메인 데이터센터 (계정계, 체결엔진, Kafka)
         ├── DR 데이터센터
         └── Monitoring 서버 (Prometheus → EKS 메트릭 수집)
```

<br>

---

## 3. 디렉토리 구조

```
Terraform/
├── network/                        # VPC, 서브넷, IGW, NAT GW, Route Table
│   ├── vpc.tf
│   ├── subnet.tf
│   ├── internet_gateway.tf
│   ├── nat_gateway.tf
│   ├── route_table.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── security_group/                 # 보안 그룹 전체 관리
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── kubernetes_cluster/             # EKS 클러스터, 노드 그룹, Add-ons, OIDC, IRSA
│   ├── main.tf
│   ├── iam_irsa.tf                 # External Secrets, LB Controller, GitHub Actions IRSA
│   ├── variables.tf
│   └── outputs.tf
│
├── database/                       # RDS MariaDB (Primary + Replica)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── cache/                          # ElastiCache Redis
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── load_balancer/                  # NLB, ALB, WAF, Route53, S3
│   ├── nlb.tf
│   ├── alb.tf
│   ├── waf.tf
│   ├── route53.tf
│   ├── s3.tf                       # Backup 버킷 + 프로필 이미지 버킷
│   ├── variables.tf
│   └── outputs.tf
│
├── bastion_host/                   # Bastion EC2 + SSM IAM Role
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── main.tf                         # 루트 모듈 — 전체 모듈 호출
├── variables.tf                    # 공통 변수 정의
├── provider.tf                     # AWS / TLS 프로바이더
├── terraform.tfvars                # 변수 실제 값 (git 제외)
└── .gitignore
```

<br>

---

## 4. 모듈별 상세 설명

### 4.1 Network

#### VPC

| 설정         | 값               | 선택 이유                                           |
| ------------ | ---------------- | --------------------------------------------------- |
| CIDR         | `10.14.0.0/16` | 65,536개 IP 확보. 향후 서브넷 추가 시에도 여유 있음 |
| DNS Hostname | 활성화           | EKS 내부 서비스 디스커버리(CoreDNS)에 필수          |
| DNS Support  | 활성화           | RDS 엔드포인트 도메인 해석에 필요                   |

<br>

#### 서브넷 (총 8개, AZ 이중화)

| 서브넷         | CIDR               | AZ | 용도                    |
| -------------- | ------------------ | -- | ----------------------- |
| public-subnetA | `10.14.10.0/24`  | 2a | NLB, Bastion, NAT GW    |
| public-subnetC | `10.14.20.0/24`  | 2c | NLB AZ 이중화           |
| EKS-subnetA    | `10.14.110.0/24` | 2a | EKS 워커 노드           |
| EKS-subnetC    | `10.14.120.0/24` | 2c | EKS 워커 노드 AZ 이중화 |
| DB-subnetA     | `10.14.210.0/24` | 2a | RDS Primary             |
| DB-subnetC     | `10.14.220.0/24` | 2c | RDS Replica             |
| Redis-subnetA  | `10.14.230.0/24` | 2a | ElastiCache Primary     |
| Redis-subnetC  | `10.14.240.0/24` | 2c | ElastiCache Replica     |

> **CIDR 설계 규칙**: 세 번째 옥텟으로 역할 구분 (10~20: Public, 110~120: EKS, 210~220: DB, 230~240: Redis). 짝수 대역이 AZ-A, 홀수 대역이 AZ-C.

역할별로 서브넷을 분리한 이유는 보안 그룹과 라우팅 정책을 세밀하게 제어하기 위함입니다. DB와 Redis 서브넷은 인터넷 경로가 없으며 EKS 노드에서의 접근만 허용합니다.

<br>

#### EKS 서브넷 태그

EKS 서브넷에는 아래 태그를 반드시 붙입니다. AWS Load Balancer Controller가 Ingress 생성 시 ALB를 배치할 서브넷을 자동으로 탐색하는 데 사용됩니다.

```
kubernetes.io/cluster/maesoongan-cluster = shared
kubernetes.io/role/internal-elb          = 1
```

Public 서브넷에는 NLB 배치를 위해 `kubernetes.io/role/elb = 1` 태그를 붙입니다.

<br>

#### NAT Gateway

Public Subnet A에 1개 배치합니다. EKS 워커 노드가 ECR에서 컨테이너 이미지를 Pull하거나 한국투자증권 API 같은 외부 서비스를 호출할 때 이 NAT GW를 통해 단방향 아웃바운드만 허용합니다.

현재는 비용 절감을 위해 AZ-A에만 1개 운영합니다. 운영 전환 시 AZ-C에 추가하여 단일 장애점을 제거합니다.

<br>

#### 라우팅 테이블

| 라우팅 테이블 | 연결 서브넷          | 아웃바운드                                |
| ------------- | -------------------- | ----------------------------------------- |
| rt-public     | Public A, C          | → IGW → 인터넷                          |
| rt-private-a  | EKS-A, DB-A, Redis-A | → NAT GW(A)                              |
| rt-private-c  | EKS-C, DB-C, Redis-C | → NAT GW(A) (이중화 시 NAT GW(C)로 분리) |

AZ별로 라우팅 테이블을 분리한 이유는 이중화 적용 시 각 AZ의 NAT GW를 독립적으로 연결하기 위해서입니다.

<br>

---

### 4.2 Security Group

최소 권한 원칙(Principle of Least Privilege)에 따라 설계했습니다. IP 대역 대신 보안 그룹 ID를 소스로 참조하여 허용 범위를 정밀하게 제어합니다.

| 보안 그룹       | 인바운드 규칙                                               | 설계 이유                                                                                  |
| --------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `alb-sg`      | 80, 443 전체 허용                                           | NLB가 클라이언트 원본 IP를 전달하므로 전체 허용. 실제 차단은 WAF가 담당                    |
| `eks-node-sg` | ALB 전체, 노드 간 전체, On-Premises 3곳(443), VPC 내부(443) | NodePort 동적 할당으로 ALB 전체 허용 필요. 노드 간 전체 허용은 vpc-cni Pod 네트워크에 필수 |
| `bastion-sg`  | SSH 22 전체 허용                                            | Session Manager 사용으로 추후 22 제거 예정                                                 |
| `rds-sg`      | EKS 노드 → 3306, Bastion → 3306                           | DB는 애플리케이션과 DBA 접근만 허용. 인터넷 직접 접근 불가                                 |
| `cache-sg`    | EKS 노드 → 6379                                            | Redis는 EKS 애플리케이션에서만 접근 가능. Bastion도 직접 접근 불가                         |

**On-Premises 3곳에 443을 허용하는 이유**: Site-to-Site VPN으로 연결된 계정계 서버, DR 서버, Prometheus 모니터링 서버에서 EKS 서비스로 접근할 수 있게 합니다.

<br>

---

### 4.3 EKS (Kubernetes Cluster)

#### 클러스터 설정

| 설정                        | 값                        | 선택 이유                                                              |
| --------------------------- | ------------------------- | ---------------------------------------------------------------------- |
| 버전                        | 1.35                      | 최신 안정 버전                                                         |
| `endpoint_public_access`  | `false`                 | EKS API 서버를 인터넷에서 완전 차단. kubectl은 Bastion을 통해서만 실행 |
| `endpoint_private_access` | `true`                  | VPC 내부(Bastion, 노드)에서는 API 서버 접근 가능                       |
| CloudWatch 로그             | api, audit, authenticator | 보안 감사 추적 및 인증 이력 기록                                       |

<br>

#### OIDC Provider

쿠버네티스 ServiceAccount에 IAM Role을 연결(IRSA)하기 위해 필요합니다. 노드 전체에 과도한 IAM 권한을 부여하는 대신, Pod 수준에서 필요한 최소 권한만 부여할 수 있습니다.

<br>

#### Add-ons

| Add-on         | 역할                   | 없으면 발생하는 문제   |
| -------------- | ---------------------- | ---------------------- |
| `vpc-cni`    | Pod에 VPC IP 직접 할당 | Pod 생성 불가          |
| `coredns`    | 클러스터 내부 DNS      | 서비스명으로 통신 불가 |
| `kube-proxy` | Service → Pod 라우팅  | Service 접근 불가      |

CoreDNS는 frontend, service 노드 그룹 생성 이후 설치합니다. Pod를 실행할 노드가 준비된 후에 설치해야 Pending 상태를 피할 수 있습니다.

<br>

#### 노드 그룹 (총 5개)

워크로드 성격별로 노드 그룹을 분리했습니다. 특정 워크로드가 리소스를 독점하여 다른 서비스에 영향을 주는 것을 방지합니다.

| 노드 그룹              | 실행 Pod                                     | desired/min/max     | 분리 이유                                                    |
| ---------------------- | -------------------------------------------- | ------------------- | ------------------------------------------------------------ |
| `nodegroup-frontend` | 사용자/관리자 UI                             | 1/1/2 (운영: 2/2/4) | 사용자 직접 접점, 고가용성 필요                              |
| `nodegroup-service`  | 주문, 알림, 관리 서비스                      | 1/1/2 (운영: 2/2/4) | 핵심 비즈니스 로직                                           |
| `nodegroup-realtime` | 실시간 시세 전송                             | 1/1/2 (운영: 2/2/4) | WebSocket 장시간 유지 + 높은 처리량. 다른 서비스와 격리 필요 |
| `nodegroup-async`    | 체결 결과 반영, 랭킹 계산, 알림 발송         | 1/1/2               | 지연 허용 가능한 비동기 작업                                 |
| `nodegroup-cicd`     | ArgoCD, Argo Rollouts, GitHub Actions Runner | 1/1/2               | 배포 중 CPU 급증이 서비스에 영향을 주지 않도록 격리          |

**실시간 시세 노드 그룹을 별도로 분리한 이유**: 한국투자증권 API를 통한 주가 데이터는 WebSocket 연결을 장시간 유지하며 초당 수천 건을 처리합니다. 서비스 노드와 리소스를 공유하면 시세 폭등 구간에서 서비스 응답 지연이 발생할 수 있습니다.

**인스턴스 타입 `t3.medium` 선택 이유**: vCPU 2개, 메모리 4GB로 모의투자 서비스 규모에 적합합니다. Burstable 인스턴스 특성상 평상시 크레딧을 축적하고 트래픽 급증 시 소비하는 방식이 비용 효율적입니다.

모든 노드 그룹은 EKS-subnetA, EKS-subnetC 양쪽에 배포되어 AZ 이중화가 적용됩니다.

<br>

---

### 4.4 Database

#### RDS MariaDB

| 항목                    | 값                  | 선택 이유                                             |
| ----------------------- | ------------------- | ----------------------------------------------------- |
| 엔진                    | MariaDB 11.4        | On-Premises 계정계 DB와 동일 엔진. 스키마 호환성 유지 |
| 인스턴스                | `db.t3.micro`     | 모의투자 서비스 초기 규모 적합                        |
| 스토리지                | 20GB / gp2 / 암호화 | 금융 데이터 저장 암호화 필수                          |
| `max_connections`     | 300                 | EKS 다수 Pod의 연결 풀 고려. 기본값(151) 초과 방지    |
| 백업 윈도우             | `03:00-04:00`     | 주식 시장 종료 후 트래픽 최저 시간대                  |
| `publicly_accessible` | `false`           | 인터넷 직접 접근 불가                                 |

<br>

#### RDS Replica (현재 비활성 — 주석 처리)

```hcl
# database/main.tf 주석 해제하여 활성화
resource "aws_db_instance" "replica" {
  identifier          = "maesoongan-mariadb-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  availability_zone   = "ap-northeast-2c"
  ...
}
```

Primary(AZ-A) 장애 시 Replica(AZ-C)로 페일오버하여 서비스를 유지합니다. 현재는 비용 절감을 위해 비활성화 상태입니다.

<br>

---

### 4.5 Cache

#### ElastiCache Redis

| 항목                           | 값                 | 선택 이유                                      |
| ------------------------------ | ------------------ | ---------------------------------------------- |
| 엔진                           | Redis 7.1          | 세션 저장, 실시간 시세 캐싱, Pub/Sub 모두 지원 |
| 인스턴스                       | `cache.t3.micro` | 초기 규모 적합                                 |
| `at_rest_encryption_enabled` | `true`           | 세션 토큰 등 민감 데이터 저장 암호화           |
| `transit_encryption_enabled` | `true`           | 네트워크 도청 방지 (TLS)                       |
| `auth_token`                 | 비밀번호           | TLS와 함께 이중 보안                           |

**Redis 활용 시나리오**

- 사용자 JWT 토큰 저장 (TTL 설정)
- 실시간 주가 데이터 Pub/Sub → WebSocket 클라이언트 즉시 전달
- DB 반복 조회 결과 캐싱

<br>

#### 이중화 적용 시 변경 (현재 비활성)

```hcl
# cache/main.tf 수정
num_cache_clusters          = 2
automatic_failover_enabled  = true
multi_az_enabled            = true
preferred_cache_cluster_azs = ["ap-northeast-2a", "ap-northeast-2c"]
```

<br>

---

### 4.6 Load Balancer

#### NLB → ALB 체이닝 구조 선택 이유

```
인터넷 → NLB (L4, 정적 IP) → WAF → ALB (L7, 경로 기반 라우팅) → EKS
```

- **NLB를 앞에 두는 이유**: Route53 Alias로 NLB의 정적 IP를 제공합니다. ALB는 IP가 동적이라 정적 IP 보장이 불가능합니다.
- **ALB를 뒤에 두는 이유**: L7 경로 기반 라우팅(`/api/*`, `/ws/*` 등)과 헬스체크 기능을 사용합니다.
- **ALB를 Internal로 설정한 이유**: NLB를 통해서만 접근 가능하도록 강제하여 WAF를 반드시 거치게 합니다.

<br>

#### WAF

| 규칙                                     | 차단 대상                                         |
| ---------------------------------------- | ------------------------------------------------- |
| `AWSManagedRulesCommonRuleSet`         | SQL Injection, XSS, 파일 인클루전 등 OWASP Top 10 |
| `AWSManagedRulesKnownBadInputsRuleSet` | Log4Shell 등 알려진 익스플로잇 패턴               |

AWS Managed Rules를 선택한 이유: AWS 보안팀이 새로운 위협 발견 시 자동으로 업데이트합니다. 별도 관리 없이 최신 위협에 대응할 수 있습니다.

<br>

#### S3 버킷 (2개)

| 버킷                          | 용도                        | 주요 설정                                                                                                       |
| ----------------------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `maesoongan-backup`         | tfstate 백업, 로그 아카이빙 | AES-256 암호화, 버전 관리, 퍼블릭 접근 전체 차단                                                                |
| `maesoongan-profile-images` | 회원 프로필 이미지 저장     | `profile-images/*` 경로 GetObject만 공개, PutObject는 IAM Role로만, CORS 설정, 수명주기(noncurrent 30일 삭제) |

<br>

#### Route53

콘솔에서 생성된 기존 Hosted Zone을 `data` 소스로 참조합니다. Hosted Zone을 Terraform으로 재생성하면 NS 레코드가 바뀌어 도메인 연결이 끊기기 때문에 참조 방식을 사용합니다.

- `{domain}` A 레코드 → NLB (Alias)
- `www.{domain}` A 레코드 → NLB (Alias)

<br>

---

### 4.7 Bastion Host

| 항목        | 값                                    | 선택 이유                                  |
| ----------- | ------------------------------------- | ------------------------------------------ |
| 인스턴스    | `t3.micro`                          | 관리 목적이므로 최소 사양                  |
| OS          | Amazon Linux 2023                     | SSM Agent 기본 내장, 최신 보안 패치        |
| 위치        | Public Subnet A                       | 단일 관리 서버이므로 이중화 불필요         |
| AMI         | `data` 소스로 최신 AL2023 자동 조회 | AMI ID 하드코딩 없이 항상 최신 이미지 사용 |
| Private Key | RSA 4096 / Terraform 자동 생성        | `terraform output`으로만 확인 가능       |

<br>

#### IAM Role (SSM 접속용)

```
aws_iam_role.bastion
  ├── AmazonSSMManagedInstanceCore  (SSM Session Manager 접속)
  └── eks-role (인라인)              (eks:DescribeCluster → kubeconfig 업데이트용)
        └── aws_iam_instance_profile.bastion
              └── aws_instance.bastion
```

SSH 22포트를 열지 않고 Session Manager로 접속합니다. 접속 이력이 CloudTrail에 자동 기록되어 감사 추적이 가능합니다.

<br>

#### Bastion 접속 및 활용

```bash
# Session Manager로 접속
aws ssm start-session --target <bastion-instance-id>

# EKS kubeconfig 연결 (Bastion에서 실행)
aws eks update-kubeconfig --region ap-northeast-2 --name maesoongan-cluster

# kubectl 사용
kubectl get nodes
kubectl get pods -A

# RDS 접속
mysql -h <rds-endpoint> -u admin -p fisaschool
```

<br>

---

## 5. IAM 설계

### EKS 관련 IAM Role

| Role                              | 정책                                               | 용도                                          |
| --------------------------------- | -------------------------------------------------- | --------------------------------------------- |
| `maesoongan-eks-cluster-role`   | AmazonEKSClusterPolicy                             | EKS 컨트롤 플레인이 VPC, EC2, ELB 관리        |
| `maesoongan-eks-nodegroup-role` | WorkerNodePolicy, CNI, ECR ReadOnly                | 워커 노드 EKS 등록, Pod 네트워크, 이미지 Pull |
| `maesoongan-bastion-role`       | AmazonSSMManagedInstanceCore + eks:DescribeCluster | Bastion SSM 접속 및 kubeconfig 업데이트       |

**ECR ReadOnly만 부여한 이유**: 워커 노드는 이미지를 읽기만 하면 됩니다. 쓰기 권한 배제로 노드 침해 시 악성 이미지 업로드를 방지합니다.

<br>

### IRSA (IAM Roles for Service Accounts)

EKS OIDC Provider를 통해 쿠버네티스 ServiceAccount에 IAM Role을 연결합니다. 노드 전체에 권한을 부여하는 방식 대신 Pod 수준 최소 권한을 적용합니다.

| Role                                                        | 대상 ServiceAccount                          | 권한                                         |
| ----------------------------------------------------------- | -------------------------------------------- | -------------------------------------------- |
| `MaesoonganExternalSecretsRole`                           | `external-secrets/external-secrets`        | Secrets Manager 읽기 (`maesoongan/prod/*`) |
| `eksctl-maesoongan-cluster-addon-iamserviceacc-Role1-...` | `kube-system/aws-load-balancer-controller` | ALB/NLB 자동 프로비저닝                      |
| `MaesoonganGitHubActionsEcrRole`                          | GitHub Actions (OIDC)                        | ECR 이미지 Push (지정 리포지토리만)          |

<br>

### GitHub Actions ECR Role

GitHub Actions OIDC를 사용하여 AWS 자격증명 없이 ECR에 이미지를 Push합니다.

허용 대상 브랜치:

- `repo:MaeSoonGan/Back-End:ref:refs/heads/main`
- `repo:MaeSoonGan/Back-End:ref:refs/heads/develop`
- `repo:MaeSoonGan/Front-End:ref:refs/heads/main`
- `repo:MaeSoonGan/Front-End:ref:refs/heads/develop`

허용 ECR 리포지토리: `maesoongan/` 하위 11개 서비스 리포지토리 (admin-service, auth-service, contest-service, market-service, market-realtime-service, user-realtime-service, order-service, trade-sync-worker, notification-api, frontend-admin, frontend-user)

<br>

### auth-service S3 정책

```hcl
# maesoongan-auth-service-s3-policy
# s3:PutObject만 허용 (profile-images/* 경로 한정)
```

auth-service가 프로필 이미지를 업로드할 때만 사용하는 최소 권한 정책입니다. 해당 정책은 auth-service IRSA Role에 연결이 필요합니다.

<br>

---

## 6. 변수 설정

### `variables.tf`

| 변수                       | 기본값         | 설명                                |
| -------------------------- | -------------- | ----------------------------------- |
| `prefix`                 | `maesoongan` | 모든 리소스명 앞에 붙는 prefix      |
| `db_password`            | 없음           | RDS 마스터 비밀번호 (`sensitive`) |
| `redis_password`         | 없음           | Redis 인증 토큰 (`sensitive`)     |
| `domain_name`            | 없음           | Route53 도메인명                    |
| `onprem_main_cidr`       | 없음           | On-Premises 메인 데이터센터 CIDR    |
| `onprem_dr_cidr`         | 없음           | On-Premises DR 데이터센터 CIDR      |
| `onprem_monitoring_cidr` | 없음           | On-Premises 모니터링 서버 CIDR      |

<br>

### `terraform.tfvars` (git 제외)

```hcl
prefix                 = "maesoongan"
db_password            = "변경 필요"
redis_password         = "변경 필요 (최소 16자)"
domain_name            = "도메인명"
onprem_main_cidr       = "x.x.x.x/xx"
onprem_dr_cidr         = "x.x.x.x/xx"
onprem_monitoring_cidr = "x.x.x.x/xx"
```

<br>

---

## 7. 실행 방법

### 최초 배포

```bash
# 1. 초기화
terraform init

# 2. 계획 확인
terraform plan

# 3. 배포
terraform apply
```

<br>

### 특정 모듈만 배포

```bash
terraform apply -target=module.network
terraform apply -target=module.kubernetes_cluster
```

<br>

### 리소스 삭제

```bash
terraform destroy
```

<br>

---

## 8. Apply 후 필수 작업

### 1단계 — kubeconfig 연결

EKS Private Endpoint이므로 VPN 연결 또는 Bastion에서 실행해야 합니다.

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name maesoongan-cluster
```

<br>

### 2단계 — AWS Load Balancer Controller 설치

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=maesoongan-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<IRSA_ROLE_ARN>
```

<br>

### 3단계 — 팀원 EKS 접근 권한 추가

```
콘솔 → EKS → maesoongan-cluster → Access 탭 → Create access entry
```

<br>

### 4단계 — Site-to-Site VPN 설정 (On-Premises 연동)

```
콘솔에서 수행:
1. Customer Gateway 생성 (On-Premises pfSense 공인 IP 입력)
2. Virtual Private Gateway 생성 → VPC 연결
3. Site-to-Site VPN Connection 생성
4. 구성 파일 다운로드 → pfSense 적용
```

<br>

### 5단계 — HTTPS 활성화 (ACM 인증서 발급 후)

```hcl
# 1. variables.tf 주석 해제
variable "acm_certificate_arn" { ... }

# 2. load_balancer/alb.tf HTTPS 리스너 주석 해제
# 3. terraform apply
```

<br>

| 작업                    | 완료 여부 |
| ----------------------- | --------- |
| kubeconfig 연결         | ☐        |
| AWS LB Controller 설치  | ☐        |
| 팀원 EKS 접근 권한 추가 | ☐        |
| VPN 설정 (pfSense 연동) | ☐        |
| HTTPS 활성화            | ☐        |

<br>

---

## 9. 이중화 적용 체크리스트

현재 개발/테스트 환경 기준으로 비용 절감을 위해 일부 이중화가 비활성화 상태입니다.

| 항목          | 현재 상태          | 운영 전환 시 변경 내용                     | 변경 파일                                              |
| ------------- | ------------------ | ------------------------------------------ | ------------------------------------------------------ |
| NAT Gateway   | 1개 (AZ-A)         | AZ-C 추가, Private RT-C를 NAT GW(C)로 분리 | `network/nat_gateway.tf`, `network/route_table.tf` |
| EKS 노드 그룹 | desired=1, min=1   | desired=2, min=2                           | `kubernetes_cluster/main.tf`                         |
| RDS Replica   | 주석 처리 (비활성) | replica 리소스 블록 주석 해제              | `database/main.tf`                                   |
| ElastiCache   | 단일 노드          | `num_cache_clusters=2`, failover 활성화  | `cache/main.tf`                                      |
| NLB           | AZ-A, C 양쪽       | **이미 적용됨**                      | —                                                     |
| ALB           | AZ-A, C 양쪽       | **이미 적용됨**                      | —                                                     |
| Bastion       | 단일 (AZ-A)        | 관리 목적이므로 이중화 불필요              | —                                                     |

<br>

---

## 10. 주의사항

- `terraform.tfvars` — git에 절대 올리지 않습니다. `.gitignore`에 포함되어 있습니다.
- `terraform.tfstate` — git에 올리지 않습니다. S3 백엔드 또는 로컬 관리합니다.
- **EKS Private Endpoint**: `kubectl` 명령은 Bastion 또는 VPN 연결 환경에서만 동작합니다.
- **Bastion Private Key**: `terraform output -raw bastion_private_key`로만 확인 가능합니다.
- **콘솔 수동 변경 금지**: 콘솔에서 리소스를 변경하면 Terraform state와 불일치가 발생합니다. 변경이 필요하면 반드시 코드를 수정하고 `terraform apply`를 실행합니다.
- **`fisaschool-ssm-ec2-role`**: 콘솔에서 수동 생성된 구 SSM Role입니다. `maesoongan-bastion-role`로 교체 완료 후 삭제합니다.
