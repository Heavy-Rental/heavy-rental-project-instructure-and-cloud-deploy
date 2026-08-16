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
  multi_az                     = false
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
