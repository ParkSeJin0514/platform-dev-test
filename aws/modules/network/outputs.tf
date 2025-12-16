# ------------------------------------------------------------
# VPC ID
# ------------------------------------------------------------
output "vpc_id" {
  description = "Main VPC ID"
  value       = aws_vpc.main.id
}

# ------------------------------------------------------------
# 선택된 가용영역 목록
# ------------------------------------------------------------
output "azs" {
  description = "Selected availability zones"
  value       = local.azs
}

# ------------------------------------------------------------
# Subnet IDs (AZ 순서대로 정렬)
# ------------------------------------------------------------
output "public_subnet_id" {
  description = "Public (bastion) subnet IDs (sorted by AZ)"
  value = [
    for az in local.azs : aws_subnet.subnet["bastion_${substr(az, -2, 2)}"].id
  ]
}

output "private_mgmt_subnet_id" {
  description = "Private mgmt subnet IDs (sorted by AZ)"
  value = [
    for az in local.azs : aws_subnet.subnet["mgmt_${substr(az, -2, 2)}"].id
  ]
}

output "private_eks_subnet_id" {
  description = "Private EKS worker node subnet IDs (sorted by AZ)"
  value = [
    for az in local.azs : aws_subnet.subnet["eks_${substr(az, -2, 2)}"].id
  ]
}

output "private_db_subnet_id" {
  description = "Private DB subnet IDs (sorted by AZ)"
  value = [
    for az in local.azs : aws_subnet.subnet["db_${substr(az, -2, 2)}"].id
  ]
}

# ------------------------------------------------------------
# NAT Gateway IDs (AZ별 Map)
# ------------------------------------------------------------
output "nat_gateway_ids" {
  description = "NAT Gateway IDs per AZ"
  value = {
    for az, gw in aws_nat_gateway.nat : az => gw.id
  }
}

# ------------------------------------------------------------
# Route Table IDs
# ------------------------------------------------------------
output "route_table_ids" {
  description = "Public and private route table IDs"
  value = {
    public = aws_route_table.public_rt.id
    private = {
      for az, rt in aws_route_table.private_rt : az => rt.id
    }
  }
}

# ------------------------------------------------------------
# 서브넷 CIDR 정보 (디버깅용)
# ------------------------------------------------------------
output "subnet_cidrs" {
  description = "All subnet CIDRs"
  value = {
    for k, v in aws_subnet.subnet : k => v.cidr_block
  }
}