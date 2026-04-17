
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  project_name = "eks-playground"
  cluster_name = "eks-playground-cluster"
}

# main vpc
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  # Both required for EKS — the cluster and nodes use DNS to discover
  # the API server endpoint and other AWS services
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.project_name}-vpc"
  }
}

# internet gateway
resource "aws_internet_gateway" "eks_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-igw"
  }
}

################################################################################
# 5. NAT Gateway + Elastic IP
#    Allows private subnet resources (EKS nodes) to make OUTBOUND connections
#    to the internet (pull container images, talk to AWS APIs) without being
#    directly reachable from the internet.
#
#    The NAT GW needs:
#      - An Elastic IP (static public IP for outbound traffic)
#      - To live in a PUBLIC subnet (it needs IGW access itself)
#
#    Cost: ~$0.045/hr + $0.045/GB processed. Single NAT saves money
#    but creates a single point of failure (AZ-a goes down → no outbound
#    from AZ-b). Fine for a lab.
################################################################################
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${local.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.eks_gw]
}

resource "aws_nat_gateway" "eks_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "${local.project_name}-nat-gw"
  }

  depends_on = [ aws_internet_gateway.eks_gw ]
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
    Name = "PublicSubnet-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

################################################################################
# 6. Private Subnets
#    These host EKS worker nodes. "Private" means no direct internet access —
#    outbound goes through the NAT Gateway.
#
#    The EKS subnet tag tells the AWS Load Balancer Controller:
#      "kubernetes.io/role/internal-elb" = 1  →  "put internal LBs here"
################################################################################
resource "aws_subnet" "private_subnets" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = local.azs[count.index]

  tags = {
    Name = "PrivateSubnet-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

################################################################################
# 4. Public Route Table
#    Routes: local VPC traffic stays local, everything else → Internet Gateway.
#    One route table shared by both public subnets.
################################################################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_gw.id
  }

  tags = {
    Name = "${local.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

################################################################################
# 7. Private Route Table
#    Routes: local VPC traffic stays local, everything else → NAT Gateway.
################################################################################
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gw.id
  }

  tags = {
    Name = "${local.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

