# ================================
# IAM Role - EKS Cluster
# ================================
resource "aws_iam_role" "eks_cluster" {
  name        = "${var.prefix}-eks-cluster-role"
  description = "EKS Cluster Control Plane Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ================================
# IAM Role - EKS Node Group
# ================================
resource "aws_iam_role" "eks_nodegroup" {
  name        = "${var.prefix}-eks-nodegroup-role"
  description = "EKS Worker Node Group Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  role       = aws_iam_role.eks_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ================================
# EKS Cluster
# ================================
resource "aws_eks_cluster" "main" {
  name     = "${var.prefix}-cluster"
  version  = "1.35"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = [var.eks_subnet_a_id, var.eks_subnet_c_id]
    security_group_ids      = [var.eks_node_sg_id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ================================
# OIDC Provider (Load Balancer Controller 등 IAM 연동용)
# ================================
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ================================
# EKS Add-ons
# ================================
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [
    aws_eks_node_group.frontend,
    aws_eks_node_group.service
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  depends_on = [aws_eks_cluster.main]
}

# ================================
# Node Group - Frontend
# 사용자 Pod, 관리자 Pod
# 장애 테스트 시 desired=2, min=2, max=4 로 변경
# ================================
resource "aws_eks_node_group" "frontend" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.prefix}-nodegroup-frontend"
  node_role_arn   = aws_iam_role.eks_nodegroup.arn
  subnet_ids      = [var.eks_subnet_a_id, var.eks_subnet_c_id]

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  disk_size      = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "frontend"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly
  ]
}

# ================================
# Node Group - Service
# 관리자서비스, 알림, 패션서비스, 중복서비스, 주문, 대회, 주문체결알림 Pod
# 장애 테스트 시 desired=2, min=2, max=4 로 변경
# ================================
resource "aws_eks_node_group" "service" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.prefix}-nodegroup-service"
  node_role_arn   = aws_iam_role.eks_nodegroup.arn
  subnet_ids      = [var.eks_subnet_a_id, var.eks_subnet_c_id]

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  disk_size      = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "service"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly
  ]
}

# ================================
# Node Group - Realtime (전용 노드)
# 실시간 시세 전송 Pod 전용
# 장애 테스트 시 desired=2, min=2, max=4 로 변경
# ================================
resource "aws_eks_node_group" "realtime" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.prefix}-nodegroup-realtime"
  node_role_arn   = aws_iam_role.eks_nodegroup.arn
  subnet_ids      = [var.eks_subnet_a_id, var.eks_subnet_c_id]

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  disk_size      = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "realtime"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly
  ]
}

# ================================
# Node Group - Async
# 체결결과반영, 랭킹계산, 알림발송, 감사로그 Pod
# ================================
resource "aws_eks_node_group" "async" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.prefix}-nodegroup-async"
  node_role_arn   = aws_iam_role.eks_nodegroup.arn
  subnet_ids      = [var.eks_subnet_a_id, var.eks_subnet_c_id]

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  disk_size      = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "async"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly
  ]
}

# ================================
# Node Group - CI/CD
# Github Action, Argo CD, Argo Rollouts
# ================================
resource "aws_eks_node_group" "cicd" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.prefix}-nodegroup-cicd"
  node_role_arn   = aws_iam_role.eks_nodegroup.arn
  subnet_ids      = [var.eks_subnet_a_id, var.eks_subnet_c_id]

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  disk_size      = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "cicd"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly
  ]
}
