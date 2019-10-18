resource "aws_vpc" "vpc" {
  cidr_block            = "${ var.vpc_cidr }"
  enable_dns_support    = true
  enable_dns_hostnames  = true
  tags                  = "${var.default_tags}"
}

resource "aws_internet_gateway" "vpc_gw" {
  vpc_id  = "${aws_vpc.vpc.id}"
  tags    = "${var.default_tags}"
}

# Create private subnet in each AZ for the worker nodes to recide in
resource "aws_subnet" "private_subnet" {
  count                   = "${length(var.azs)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${element(var.priv_subnet_cidrs, count.index)}"
  availability_zone       = "${format("%s%s", element(list(var.aws_region), count.index), element(var.azs, count.index))}"
  tags                    = "${var.default_tags}"
}

# Create public subnet in each AZ for public facing nodes to reside in
resource "aws_subnet" "public_subnet" {
  count                   = "${length(var.azs)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${element(var.pub_subnet_cidrs, count.index)}"
  availability_zone       = "${format("%s%s", element(list(var.aws_region), count.index), element(var.azs, count.index))}"
  tags                    = "${var.default_tags}"
}

# Create Elastic IP for NAT gateway in each AZ
resource "aws_eip" "ngw_eip" {
  count = "${length(var.azs)}"
  vpc   = "true"
  tags  = "${var.default_tags}"
}

# Create NAT gateways for the private networks in each AZ
resource "aws_nat_gateway" "nat_gateway" {
  count                   = "${length(var.azs)}"
  allocation_id           = "${element(aws_eip.ngw_eip.*.id, count.index)}"
  subnet_id               = "${element(aws_subnet.public_subnet.*.id, count.index)}"

  tags                    = "${var.default_tags}"

  depends_on = ["aws_internet_gateway.vpc_gw"]
}

resource "aws_route_table" "priv_net_route" {
  count = "${length(var.azs)}"
  vpc_id = "${aws_vpc.vpc.id}"

#  route {
#    cidr_block = "${var.vpc_cidr}"
#    gateway_id = "${aws_internet_gateway.vpc_gw.id}"
#  }

  route {
    cidr_block      = "0.0.0.0/0"
    nat_gateway_id  = "${element(aws_nat_gateway.nat_gateway.*.id, count.index)}"
  }

  tags              = "${var.default_tags}"
}

resource "aws_route_table_association" "a" {
  count          = "${length(var.azs)}"
  subnet_id      = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.priv_net_route.*.id, count.index)}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.vpc_gw.id}"
}

# private S3 endpoint
data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

data "aws_vpc_endpoint_service" "ec2" {
  service = "ec2"
}

resource "aws_vpc_endpoint" "private_s3" {
  vpc_id       = "${aws_vpc.vpc.id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
}

resource "aws_vpc_endpoint" "private_ec2" {
  vpc_id       = "${aws_vpc.vpc.id}"
  service_name = "${data.aws_vpc_endpoint_service.ec2.service_name}"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true

  security_group_ids = [
    "${aws_security_group.default.id}"
  ]

  subnet_ids = [
    "${aws_subnet.private_subnet.*.id}"
  ]
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = "${length(var.azs)}"
  vpc_endpoint_id = "${aws_vpc_endpoint.private_s3.id}"
  route_table_id  = "${element(aws_route_table.priv_net_route.*.id, count.index)}"
}

resource "aws_security_group" "default" {
  name = "my_default_sg" # TODO: Extract name
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
    self        = true
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags          = "${var.default_tags}"
}
