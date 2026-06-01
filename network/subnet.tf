resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.14.10.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.prefix}-public-subnetA"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.14.20.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.prefix}-public-subnetC"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "eks_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.14.110.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name                                          = "${var.prefix}-EKS-subnetA"
    "kubernetes.io/cluster/${var.prefix}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

resource "aws_subnet" "eks_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.14.120.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name                                          = "${var.prefix}-EKS-subnetC"
    "kubernetes.io/cluster/${var.prefix}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.14.210.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "${var.prefix}-DB-subnetA"
  }
}

resource "aws_subnet" "db_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.14.220.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "${var.prefix}-DB-subnetC"
  }
}

resource "aws_subnet" "redis_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.14.230.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "${var.prefix}-Redis-subnetA"
  }
}

resource "aws_subnet" "redis_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.14.240.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "${var.prefix}-Redis-subnetC"
  }
}
