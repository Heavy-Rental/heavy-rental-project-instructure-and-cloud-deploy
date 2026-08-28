# Names match AWS study §6.2. Rules are separate resources to avoid cycles.

# AWS forbids security-group *names* that start with sg- (reserved for ids).
# Study names live on the Name tag.

resource "aws_security_group" "alb_public" {
  name        = "hr-alb-public"
  description = "Internet-facing portal ALB :80"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-alb-public" }
}

resource "aws_security_group" "alb_rest" {
  name        = "hr-alb-rest"
  description = "Internet-facing REST ALB :8080"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-alb-rest" }
}

resource "aws_security_group" "alb_haystack" {
  name        = "hr-alb-haystack"
  description = "Internal Haystack ALB :8000"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-alb-haystack" }
}

resource "aws_security_group" "portal" {
  name        = "hr-portal"
  description = "asg-portal nginx"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-portal" }
}

resource "aws_security_group" "rest" {
  name        = "hr-rest"
  description = "asg-rest Tomcat"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-rest" }
}

resource "aws_security_group" "haystack" {
  name        = "hr-haystack"
  description = "asg-haystack uvicorn"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-haystack" }
}

resource "aws_security_group" "rds" {
  name        = "hr-rds"
  description = "RDS Postgres :5432"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-rds" }
}

resource "aws_security_group" "neo4j" {
  name        = "hr-neo4j"
  description = "asg-neo4j Bolt"
  vpc_id      = aws_vpc.academy.id
  tags        = { Name = "sg-neo4j" }
}

# --- public ALB ---
resource "aws_vpc_security_group_ingress_rule" "alb_public_http" {
  security_group_id = aws_security_group.alb_public.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Internet to portal ALB"
}

resource "aws_vpc_security_group_egress_rule" "alb_public_to_portal" {
  security_group_id            = aws_security_group.alb_public.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.portal.id
}

# --- portal ---
resource "aws_vpc_security_group_ingress_rule" "portal_from_alb" {
  security_group_id            = aws_security_group.portal.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb_public.id
}

resource "aws_vpc_security_group_egress_rule" "portal_to_rest_alb" {
  security_group_id            = aws_security_group.portal.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb_rest.id
}

resource "aws_vpc_security_group_egress_rule" "portal_https" {
  security_group_id = aws_security_group.portal.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  description       = "SSM / ECR / Secrets Manager via NAT Gateway"
}

resource "aws_vpc_security_group_egress_rule" "portal_http" {
  security_group_id = aws_security_group.portal.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# --- internet-facing REST ALB ---
resource "aws_vpc_security_group_ingress_rule" "alb_rest_from_internet" {
  security_group_id = aws_security_group.alb_rest.id
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Internet to REST ALB :8080"
}

resource "aws_vpc_security_group_ingress_rule" "alb_rest_from_portal" {
  security_group_id            = aws_security_group.alb_rest.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.portal.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_rest_health" {
  security_group_id            = aws_security_group.alb_rest.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb_rest.id
}

resource "aws_vpc_security_group_egress_rule" "alb_rest_to_rest" {
  security_group_id            = aws_security_group.alb_rest.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.rest.id
}

# --- rest ---
resource "aws_vpc_security_group_ingress_rule" "rest_from_alb" {
  security_group_id            = aws_security_group.rest.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb_rest.id
}

resource "aws_vpc_security_group_egress_rule" "rest_to_alb" {
  security_group_id            = aws_security_group.rest.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb_rest.id
  description                  = "REST to REST ALB"
}

resource "aws_vpc_security_group_ingress_rule" "rest_from_rds" {
  security_group_id            = aws_security_group.rest.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id
  description                  = "RDS Postgres to REST"
}

resource "aws_vpc_security_group_egress_rule" "rest_to_rds" {
  security_group_id            = aws_security_group.rest.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_ingress_rule" "rest_from_haystack_alb" {
  security_group_id            = aws_security_group.rest.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb_haystack.id
  description                  = "Haystack ALB to REST"
}

resource "aws_vpc_security_group_egress_rule" "rest_to_haystack_alb" {
  security_group_id            = aws_security_group.rest.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb_haystack.id
}

resource "aws_vpc_security_group_egress_rule" "rest_https" {
  security_group_id = aws_security_group.rest.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "rest_http" {
  security_group_id = aws_security_group.rest.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# --- internal Haystack ALB ---
resource "aws_vpc_security_group_ingress_rule" "alb_haystack_from_rest" {
  security_group_id            = aws_security_group.alb_haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.rest.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_haystack_health" {
  security_group_id            = aws_security_group.alb_haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb_haystack.id
  description                  = "Haystack ALB same-subnet health / hairpin"
}

resource "aws_vpc_security_group_egress_rule" "alb_haystack_to_rest" {
  security_group_id            = aws_security_group.alb_haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.rest.id
  description                  = "Haystack ALB to REST"
}

resource "aws_vpc_security_group_egress_rule" "alb_haystack_to_self" {
  security_group_id            = aws_security_group.alb_haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb_haystack.id
  description                  = "Haystack ALB to Haystack ALB"
}

resource "aws_vpc_security_group_egress_rule" "alb_haystack_to_haystack" {
  security_group_id            = aws_security_group.alb_haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.haystack.id
}

# --- haystack ---
resource "aws_vpc_security_group_ingress_rule" "haystack_from_alb" {
  security_group_id            = aws_security_group.haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb_haystack.id
}

resource "aws_vpc_security_group_egress_rule" "haystack_to_rds" {
  security_group_id            = aws_security_group.haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_egress_rule" "haystack_to_neo4j_bolt" {
  security_group_id            = aws_security_group.haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 7687
  to_port                      = 7687
  referenced_security_group_id = aws_security_group.neo4j.id
}

resource "aws_vpc_security_group_egress_rule" "haystack_to_neo4j_browser" {
  security_group_id            = aws_security_group.haystack.id
  ip_protocol                  = "tcp"
  from_port                    = 7474
  to_port                      = 7474
  referenced_security_group_id = aws_security_group.neo4j.id
}

resource "aws_vpc_security_group_egress_rule" "haystack_https" {
  security_group_id = aws_security_group.haystack.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "haystack_http" {
  security_group_id = aws_security_group.haystack.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# --- rds ---
resource "aws_vpc_security_group_ingress_rule" "rds_from_rest" {
  security_group_id            = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rest.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_haystack" {
  security_group_id            = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.haystack.id
}

resource "aws_vpc_security_group_egress_rule" "rds_to_rest" {
  security_group_id            = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rest.id
  description                  = "RDS Postgres to REST"
}

# --- neo4j ---
resource "aws_vpc_security_group_ingress_rule" "neo4j_bolt_from_haystack" {
  security_group_id            = aws_security_group.neo4j.id
  ip_protocol                  = "tcp"
  from_port                    = 7687
  to_port                      = 7687
  referenced_security_group_id = aws_security_group.haystack.id
}

resource "aws_vpc_security_group_ingress_rule" "neo4j_bolt_from_vpc" {
  security_group_id = aws_security_group.neo4j.id
  ip_protocol       = "tcp"
  from_port         = 7687
  to_port           = 7687
  cidr_ipv4         = local.vpc_cidr
  description       = "Bolt via internal NLB node IPs"
}

# Same-subnet NLB health can appear to come from the instance itself.
resource "aws_vpc_security_group_ingress_rule" "neo4j_bolt_from_self" {
  security_group_id            = aws_security_group.neo4j.id
  ip_protocol                  = "tcp"
  from_port                    = 7687
  to_port                      = 7687
  referenced_security_group_id = aws_security_group.neo4j.id
  description                  = "NLB same-subnet health / hairpin"
}

resource "aws_vpc_security_group_ingress_rule" "neo4j_browser_from_haystack" {
  security_group_id            = aws_security_group.neo4j.id
  ip_protocol                  = "tcp"
  from_port                    = 7474
  to_port                      = 7474
  referenced_security_group_id = aws_security_group.haystack.id
}

resource "aws_vpc_security_group_egress_rule" "neo4j_https" {
  security_group_id = aws_security_group.neo4j.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "neo4j_http" {
  security_group_id = aws_security_group.neo4j.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}


