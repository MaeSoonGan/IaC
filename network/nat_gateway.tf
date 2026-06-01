resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name = "${var.prefix}-eip-nat-gw-a"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.prefix}-nat-gw-a"
  }

  depends_on = [aws_internet_gateway.main]
}
