resource "aws_vpc" "academy" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "heavy-rental-academy"
  }
}

resource "aws_internet_gateway" "academy" {
  vpc_id = aws_vpc.academy.id

  tags = {
    Name = "igw-heavy-rental-academy"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.academy.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  count                   = 2
  vpc_id                  = aws_vpc.academy.id
  cidr_block              = local.app_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "app-${local.azs[count.index]}"
    Tier = "private-app"
  }
}

resource "aws_subnet" "data" {
  count                   = 2
  vpc_id                  = aws_vpc.academy.id
  cidr_block              = local.data_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "data-${local.azs[count.index]}"
    Tier = "private-data"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.academy.id

  tags = {
    Name = "rt-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.academy.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.academy.id

  tags = {
    Name = "rt-app"
  }
}

resource "aws_route" "app_nat" {
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.academy.id

  tags = {
    Name = "rt-data"
  }
}

resource "aws_route" "data_nat" {
  route_table_id         = aws_route_table.data.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}

resource "aws_route_table_association" "data" {
  count          = 2
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# Free. Reduces NAT traffic for ECR/S3 layers.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.academy.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.app.id,
    aws_route_table.data.id,
  ]

  tags = {
    Name = "vpce-s3-academy"
  }
}
