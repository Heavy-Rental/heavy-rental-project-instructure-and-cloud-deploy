# Two NAT Gateways (one per public AZ). Not a NAT instance.
# Private app/data in each AZ use the Gateway in that AZ.
# Gateways cannot be stopped; they bill until terraform destroy.

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "eip-nat-${local.azs[count.index]}"
    Role = "nat"
  }
}

resource "aws_nat_gateway" "this" {
  count             = 2
  allocation_id     = aws_eip.nat[count.index].id
  subnet_id         = aws_subnet.public[count.index].id
  connectivity_type = "public"

  tags = {
    Name = "natgw-${local.azs[count.index]}"
    Role = "nat"
  }

  depends_on = [aws_internet_gateway.academy]
}
