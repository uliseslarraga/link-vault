locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.subnets_per_region)

  common_tags = merge(
    {
      Environment = var.env
      ManagedBy   = "terraform"
      Project     = "link-vault"
    },
    var.tags,
  )
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ───────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required for RDS endpoint resolution and EKS

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-vpc" })
}

# ── Fix #2 — Lock the default Security Group ──────────────────────────────────
# The default SG allows all inbound from itself. Explicitly removing all rules
# prevents resources accidentally launched without an SG from having open access.

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  # No ingress or egress rules — deny all traffic
  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-sg-default-DENY-ALL" })
}

# ── Fix #1 — VPC Flow Logs ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/link-vault-${var.env}"
  retention_in_days = var.flow_log_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  name = "link-vault-${var.env}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "link-vault-${var.env}-vpc-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-flow-log" })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-igw" })
}

# ── Subnets ───────────────────────────────────────────────────────────────────

# Fix #5 — count now driven by var.subnets_per_region (was hardcoded to 3)
# Fix #7 — map_public_ip_on_launch driven by variable (default false)

resource "aws_subnet" "public" {
  count = var.subnets_per_region

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    local.common_tags,
    {
      Name = "link-vault-${var.env}-public-${local.azs[count.index]}"
      Tier = "public"
    },
    var.eks_enabled ? { "kubernetes.io/role/elb" = "1" } : {},
    var.eks_enabled ? { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" } : {},
  )
}

resource "aws_subnet" "private" {
  count = var.subnets_per_region

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + var.subnets_per_region)
  availability_zone = local.azs[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "link-vault-${var.env}-private-${local.azs[count.index]}"
      Tier = "private"
    },
    var.eks_enabled ? { "kubernetes.io/role/internal-elb" = "1" } : {},
    var.eks_enabled ? { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" } : {},
  )
}

resource "aws_subnet" "data" {
  count = var.subnets_per_region

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + (var.subnets_per_region * 2))
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "link-vault-${var.env}-data-${local.azs[count.index]}"
    Tier = "data"
  })
}

# ── Route Tables ──────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count = var.subnets_per_region

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-rt-private" })
}

resource "aws_route_table_association" "private" {
  count = var.subnets_per_region

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-rt-data" })
}

resource "aws_route_table_association" "data" {
  count = var.subnets_per_region

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# ── NAT Gateway ───────────────────────────────────────────────────────────────
# Provides outbound internet access for private and data subnets (EKS nodes,
# ECR image pulls, AWS API calls, etc.) without exposing them directly.
#
# single_nat_gateway = true  → one NAT in public subnet[0] (dev/cost-effective)
# single_nat_gateway = false → one NAT per AZ (prod HA — also requires
#                              per-AZ private/data route tables, see README)

resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : var.subnets_per_region
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "link-vault-${var.env}-eip-nat${var.single_nat_gateway ? "" : "-${local.azs[count.index]}"}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.single_nat_gateway ? 1 : var.subnets_per_region

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "link-vault-${var.env}-nat${var.single_nat_gateway ? "" : "-${local.azs[count.index]}"}"
  })

  depends_on = [aws_internet_gateway.this]
}

# Default route via NAT for private and data tiers.
# Both share the same single route table today, so they reference nat[0].
# For per-AZ NAT (single_nat_gateway = false), refactor to per-AZ route tables.

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route" "data_nat" {
  route_table_id         = aws_route_table.data.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# ── VPC Gateway Endpoint — S3 ─────────────────────────────────────────────────
# Free endpoint — keeps S3 traffic (ECR layers, app uploads) on the AWS backbone
# without going through the NAT Gateway (which charges per GB).
# Associated with all three route tables so every tier benefits.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id,
    aws_route_table.data.id,
  ]

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-vpce-s3" })
}
