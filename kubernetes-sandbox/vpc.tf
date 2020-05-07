terraform {
  backend "s3" {
    bucket = "albersm.terraform-state"
    key    = "kubernetes-sandbox"
    region = "us-west-2"
  }
}

provider "aws" {
  region  = "us-west-2"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = var.name
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.0.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_subnet" "private" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_eip" "nat-gateway" {
  depends_on = [aws_internet_gateway.internet-gateway]  // See resource documentation.
  vpc = true
  tags = {
    Name = var.name
  }
}

resource "aws_nat_gateway" "gateway" {
  allocation_id = aws_eip.nat-gateway.id
  subnet_id = aws_subnet.public.id
  tags = {
    Name = var.name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public.id
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet-gateway.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private.id
}

resource "aws_route" "private" {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.gateway.id
  route_table_id = aws_route_table.private.id
}
