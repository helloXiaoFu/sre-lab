# ============================================================================
# Outputs Configuration for Mao Quotes API
# ============================================================================
# 用途：导出重要信息，供其他模块或脚本使用
# ============================================================================

# ----------------------------------------------------------------------------
# ECR Repository信息
# ----------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "Full URL of the ECR repository"
  value       = aws_ecr_repository.mao_quotes.repository_url

  # 示例输出：
  # <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api-dev
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.mao_quotes.arn

  # 示例输出：
  # arn:aws:ecr:us-east-1:<YOUR_AWS_ACCOUNT_ID>:repository/mao-quotes-api-dev
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.mao_quotes.name
}

output "ecr_registry_id" {
  description = "Registry ID (AWS account ID)"
  value       = aws_ecr_repository.mao_quotes.registry_id
}

# ----------------------------------------------------------------------------
# Docker命令（便于使用）
# ----------------------------------------------------------------------------

output "docker_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.mao_quotes.repository_url}"

  # 使用方法：
  # $(terraform output -raw docker_login_command)
}

output "docker_build_command" {
  description = "Example docker build command"
  value       = "docker build -t ${aws_ecr_repository.mao_quotes.repository_url}:latest -f docker/Dockerfile ."
}

output "docker_push_command" {
  description = "Example docker push command"
  value       = "docker push ${aws_ecr_repository.mao_quotes.repository_url}:latest"
}

# ----------------------------------------------------------------------------
# 环境信息
# ----------------------------------------------------------------------------

output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# ----------------------------------------------------------------------------
# 完整的镜像URI（带标签）
# ----------------------------------------------------------------------------

output "full_image_uri_latest" {
  description = "Full image URI with 'latest' tag"
  value       = "${aws_ecr_repository.mao_quotes.repository_url}:latest"
}

output "full_image_uri_v1" {
  description = "Full image URI with 'v1' tag"
  value       = "${aws_ecr_repository.mao_quotes.repository_url}:v1"
}

# ----------------------------------------------------------------------------
# VPC Outputs
# ----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = try(module.vpc.vpc_id, null)
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = try(module.vpc.vpc_cidr_block, null)
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = try(module.vpc.private_subnets, [])
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = try(module.vpc.public_subnets, [])
}

# ----------------------------------------------------------------------------
# EKS Outputs
# ----------------------------------------------------------------------------

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = try(module.eks.cluster_id, null)
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = try(module.eks.cluster_endpoint, null)
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = try(module.eks.cluster_name, null)
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = try(module.eks.cluster_version, null)
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = try(module.eks.cluster_security_group_id, null)
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = try(module.eks.node_security_group_id, null)
}

# ----------------------------------------------------------------------------
# kubectl配置命令
# ----------------------------------------------------------------------------

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = try("aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}", "EKS cluster not created")
}

# ============================================================================
# Outputs使用指南
# ============================================================================
#
# 1. 查看所有输出：
#    terraform output
#
# 2. 查看特定输出：
#    terraform output ecr_repository_url
#
# 3. 获取原始值（不带引号，适合脚本使用）：
#    terraform output -raw ecr_repository_url
#
# 4. 在脚本中使用：
#    ECR_URL=$(terraform output -raw ecr_repository_url)
#    docker tag myapp:v1 $ECR_URL:v1
#    docker push $ECR_URL:v1
#
# 5. 在其他Terraform模块中引用：
#    data "terraform_remote_state" "ecr" {
#      backend = "s3"
#      config = {
#        bucket = "my-terraform-state"
#        key    = "ecr/terraform.tfstate"
#        region = "us-east-1"
#      }
#    }
#    
#    # 引用输出
#    image = data.terraform_remote_state.ecr.outputs.full_image_uri_latest
#
# 6. 输出JSON格式：
#    terraform output -json
#
# 7. 敏感输出（不显示在命令行）：
#    output "db_password" {
#      value     = aws_db_instance.main.password
#      sensitive = true  # 使用 terraform output db_password 才会显示
#    }
#
# ============================================================================
