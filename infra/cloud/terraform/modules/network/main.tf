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
  enable_dns_hostnames = true # required for Interface VPC endpoints

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

  tags = merge(local.common_tags, {
    Name = "link-vault-${var.env}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = var.subnets_per_region

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + var.subnets_per_region)
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "link-vault-${var.env}-private-${local.azs[count.index]}"
    Tier = "private"
  })
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

# ── Security Group — VPC Endpoints ───────────────────────────────────────────

resource "aws_security_group" "vpc_endpoints" {
  name        = "link-vault-${var.env}-sg-vpc-endpoints"
  description = "Allow HTTPS from VPC to Interface endpoints (SSM)"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "link-vault-${var.env}-sg-vpc-endpoints" })
}

# ── VPC Interface Endpoints — SSM ─────────────────────────────────────────────

locals {
  ssm_endpoint_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(local.ssm_endpoint_services)

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.common_tags, {
    Name = "link-vault-${var.env}-vpce-${each.key}"
  })
}
