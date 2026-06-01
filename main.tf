module "network" {
  source = "./network"

  prefix   = var.prefix
  vpc_cidr = "10.14.0.0/16"
  vpc_name = "${var.prefix}-vpc"
}

module "security_group" {
  source = "./security_group"

  prefix                 = var.prefix
  vpc_id                 = module.network.vpc_id
  onprem_main_cidr       = var.onprem_main_cidr
  onprem_dr_cidr         = var.onprem_dr_cidr
  onprem_monitoring_cidr = var.onprem_monitoring_cidr
}

module "kubernetes_cluster" {
  source = "./kubernetes_cluster"

  prefix          = var.prefix
  eks_subnet_a_id = module.network.eks_subnet_a_id
  eks_subnet_c_id = module.network.eks_subnet_c_id
  eks_node_sg_id  = module.security_group.eks_node_sg_id
}

module "database" {
  source = "./database"

  prefix         = var.prefix
  db_subnet_a_id = module.network.db_subnet_a_id
  db_subnet_c_id = module.network.db_subnet_c_id
  rds_sg_id      = module.security_group.rds_sg_id
  db_password    = var.db_password
}

module "cache" {
  source = "./cache"

  prefix            = var.prefix
  redis_subnet_a_id = module.network.redis_subnet_a_id
  redis_subnet_c_id = module.network.redis_subnet_c_id
  cache_sg_id       = module.security_group.cache_sg_id
  redis_password    = var.redis_password
}

module "bastion_host" {
  source = "./bastion_host"

  prefix             = var.prefix
  public_subnet_a_id = module.network.public_subnet_a_id
  bastion_sg_id      = module.security_group.bastion_sg_id
}

module "load_balancer" {
  source = "./load_balancer"

  prefix             = var.prefix
  vpc_id             = module.network.vpc_id
  public_subnet_a_id = module.network.public_subnet_a_id
  public_subnet_c_id = module.network.public_subnet_c_id
  alb_sg_id          = module.security_group.alb_sg_id
  domain_name        = var.domain_name
  # acm_certificate_arn = var.acm_certificate_arn  # HTTPS 사용 시 활성화
}
