output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.eks_nat_gw.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.eks_gw.id
}

output "route_table_public_id" {
  value = aws_route_table.public_rt.id
}

output "route_table_private_id" {
  value = aws_route_table.private_rt.id
}