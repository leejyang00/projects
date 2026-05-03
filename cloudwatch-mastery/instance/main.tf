
# --- Data Sources ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "example" {
    ami           = data.aws_ami.amazon_linux.id
    instance_type = "t3.micro"

    monitoring = true
    iam_instance_profile = aws_iam_instance_profile.example_instance.id
    subnet_id = aws_subnet.public_subnets[0].id
    key_name = "cw-lab-key"

    vpc_security_group_ids = [ aws_security_group.instance_sg.id ]

    tags = {
        Name = "test-instance"
        Project = "CWMT"
    }

    depends_on = [ aws_subnet.public_subnets, aws_security_group.instance_sg ]
}

resource "aws_security_group" "instance_sg" {
    name        = "instance-sg"
    description = "Allow SSH and ICMP"
    vpc_id      = aws_vpc.main.id

    tags = {
        Name = "instance-sg"
    }
}
# 101.115.170.230

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_ipv4         =  "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}