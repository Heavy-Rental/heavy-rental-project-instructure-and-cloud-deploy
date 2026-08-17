# AWS requires the subnet group to span 2 AZs. Multi-AZ uses both.
resource "aws_db_subnet_group" "data" {
  name       = "heavy-rental-data"
  subnet_ids = aws_subnet.data[*].id

  tags = {
    Name = "heavy-rental-data"
  }
}

resource "aws_db_instance" "heavy_rental" {
  identifier     = "heavy-rental-academy"
  engine         = "postgres"
  engine_version = data.aws_rds_engine_version.postgres.version
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_master_username
  password = var.db_master_password
  port     = 5432

  db_subnet_group_name         = aws_db_subnet_group.data.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  multi_az                     = true
  publicly_accessible          = false
  deletion_protection          = false
  skip_final_snapshot          = true
  backup_retention_period      = 1
  auto_minor_version_upgrade   = true
  apply_immediately            = true
  performance_insights_enabled = false
  monitoring_interval          = 0
  copy_tags_to_snapshot        = false

  tags = {
    Name = "heavy-rental-academy"
    Role = "postgres-sor"
  }
}

# Second Postgres (Haystack / pgvector). Same subnet group, SG, class, and password.
# The GitHub runner cannot CREATE DATABASE on the private primary, so this is
# a second instance, not a second db name on heavy-rental-academy.
resource "aws_db_instance" "haystack" {
  identifier     = "heavy-rental-haystack-academy"
  engine         = "postgres"
  engine_version = data.aws_rds_engine_version.postgres.version
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_haystack_name
  username = var.db_master_username
  password = var.db_master_password
  port     = 5432

  db_subnet_group_name         = aws_db_subnet_group.data.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  multi_az                     = true
  publicly_accessible          = false
  deletion_protection          = false
  skip_final_snapshot          = true
  backup_retention_period      = 1
  auto_minor_version_upgrade   = true
  apply_immediately            = true
  performance_insights_enabled = false
  monitoring_interval          = 0
  copy_tags_to_snapshot        = false

  tags = {
    Name = "heavy-rental-haystack-academy"
    Role = "postgres-haystack"
  }
}
