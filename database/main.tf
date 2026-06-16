resource "aws_db_parameter_group" "main" {
  family = "mariadb11.4"
  name   = "${var.prefix}-mariadb-params"

  parameter {
    name  = "max_connections"
    value = "300"
  }

  tags = {
    Name = "${var.prefix}-mariadb-params"
  }
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.prefix}-db-subnet-group"
  description = "DB Subnet Group"
  subnet_ids  = [var.db_subnet_a_id, var.db_subnet_c_id]

  tags = {
    Name = "${var.prefix}-db-subnet-group"
  }
}

resource "aws_db_instance" "primary" {
  identifier     = "${var.prefix}-mariadb-primary"
  engine         = "mariadb"
  engine_version = "11.4"
  instance_class = "db.t3.micro"

  db_name  = "fisaschool"
  username = "admin"
  password = var.db_password

  allocated_storage     = 20
  storage_type          = "gp2"
  storage_encrypted     = true
  max_allocated_storage = 0

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  availability_zone      = "ap-northeast-2a"
  publicly_accessible    = false

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  skip_final_snapshot = true

  tags = {
    Name = "${var.prefix}-mariadb-primary"
  }
}

resource "aws_db_instance" "replica" {
  identifier          = "${var.prefix}-mariadb-replica"
  instance_class      = "db.t3.micro"
  replicate_source_db = aws_db_instance.primary.identifier

  vpc_security_group_ids = [var.rds_sg_id]
  availability_zone      = "ap-northeast-2c"
  publicly_accessible    = false

  skip_final_snapshot = true

  tags = {
    Name = "${var.prefix}-mariadb-replica"
  }

  depends_on = [aws_db_instance.primary]
}
