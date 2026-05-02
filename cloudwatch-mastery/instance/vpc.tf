data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 1)
}

# main vpc
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  # Both required for EKS — the cluster and nodes use DNS to discover
  # the API server endpoint and other AWS services
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cloudwatch-mastery-vpc"
    Project = "CWMT"
  }
}

################################################################################
# 3. Public Subnets
#    These host load balancers (ALB/NLB) — NOT the EKS nodes.
#    "Public" means they have a route to the IGW and can auto-assign public IPs.
#
#    The EKS subnet tag tells the AWS Load Balancer Controller:
#      "kubernetes.io/role/elb" = 1  →  "put internet-facing LBs here"
################################################################################
resource "aws_subnet" "public_subnets" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = local.azs[count.index]

  # instances launched here gets a public IP by default
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-CWMT-${local.azs[count.index]}"
    Project = "CWMT"
  }

  depends_on = [ aws_vpc.main ]
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

