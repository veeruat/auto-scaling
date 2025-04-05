# Define a vpc
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.prefix}"
    createdBy = "infra-${var.prefix}/base"
  }
}

# Internet gateway for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name = "Public gateway"
    createdBy = "infra-${var.prefix}/base"
  }
}


################ newly created

resource "aws_subnet" "public_a" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = var.pubsubnet_a_cidr
  availability_zone = "${var.region}a"

  tags = {
    Name = "public_a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = var.pubsubnet_b_cidr
  availability_zone = "${var.region}b"

  tags = {
    Name = "public_b"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = var.pubsubnet_c_cidr
  availability_zone = "${var.region}c"

  tags = {
    Name = "public_c"
  }
}

# Routing table for public subnets
resource "aws_route_table" "public_subnet_routes" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags = {
    Name = "Public subnet routing table"
    createdBy = "infra-${var.prefix}/base"
  }
}

# Associate the routing table to public subnet A
resource "aws_route_table_association" "public_subnet_routes_assn_a" {
  subnet_id = "${aws_subnet.public_a.id}"
  route_table_id = "${aws_route_table.public_subnet_routes.id}"
}

# Associate the routing table to public subnet B
resource "aws_route_table_association" "public_subnet_routes_assn_b" {
  subnet_id = "${aws_subnet.public_b.id}"
  route_table_id = "${aws_route_table.public_subnet_routes.id}"
}

# Associate the routing table to public subnet C
resource "aws_route_table_association" "public_subnet_routes_assn_c" {
  subnet_id = "${aws_subnet.public_c.id}"
  route_table_id = "${aws_route_table.public_subnet_routes.id}"
}
