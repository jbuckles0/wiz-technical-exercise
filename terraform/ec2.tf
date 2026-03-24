# EC2 MongoDB VM
# WEAKNESS: Using Ubuntu 20.04 which is EOL
data "aws_ami" "ubuntu_20_04" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH Key Pair
resource "tls_private_key" "mongo_vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "mongo_vm" {
  key_name   = "${var.project_name}-mongo-vm"
  public_key = tls_private_key.mongo_vm.public_key_openssh
  tags       = var.tags
}

# Store SSH key in SSM Parameter Store
resource "aws_ssm_parameter" "mongo_vm_key" {
  name        = "/${var.project_name}/mongo_vm_ssh_key"
  description = "SSH private key for MongoDB VM"
  type        = "SecureString"
  value       = tls_private_key.mongo_vm.private_key_pem
}

# Security Group
resource "aws_security_group" "mongo_vm" {
  name        = "${var.project_name}-mongo-vm-sg"
  description = "MongoDB VM security group"
  vpc_id      = module.vpc.vpc_id

  # WEAKNESS: SSH exposed to the public internet
  ingress {
    description = "SSH open to internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB restricted to EKS nodes only
  ingress {
    description     = "MongoDB from EKS nodes only"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-mongo-vm-sg" })
}

# IAM Role
resource "aws_iam_role" "mongo_vm" {
  name = "${var.project_name}-mongo-vm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# WEAKNESS: Overly permissive IAM policy (only s3:putObject is needed)
resource "aws_iam_role_policy" "mongo_vm_overpermissive" {
  name = "overpermissive-policy"
  role = aws_iam_role.mongo_vm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:*", "s3:*", "iam:*"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "mongo_vm" {
  name = "${var.project_name}-mongo-vm-profile"
  role = aws_iam_role.mongo_vm.name
}

# EC2 Instance
resource "aws_instance" "mongo_vm" {
  ami                         = data.aws_ami.ubuntu_20_04.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.mongo_vm.key_name
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.mongo_vm.id]
  iam_instance_profile        = aws_iam_instance_profile.mongo_vm.name

  user_data = templatefile("${path.module}/scripts/mongo-userdata.sh", {
    mongo_admin_password = var.mongo_admin_password
    mongo_app_password   = var.mongo_app_password
    backup_bucket        = aws_s3_bucket.mongo_backup.bucket
    aws_region           = var.aws_region
  })

  depends_on = [module.eks]

  tags = merge(var.tags, { Name = "${var.project_name}-mongo-vm" })
}
