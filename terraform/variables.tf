# ============================================================================
# Variables Configuration for Mao Quotes API
# ============================================================================
# 用途：定义可配置的变量，实现参数化和多环境支持
# ============================================================================

# ----------------------------------------------------------------------------
# AWS基础配置
# ----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in format: us-east-1, eu-west-2, etc."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# ----------------------------------------------------------------------------
# 项目配置
# ----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "mao-quotes-api"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "owner" {
  description = "Team or person responsible for the infrastructure"
  type        = string
  default     = "sre-team"
}

# ----------------------------------------------------------------------------
# ECR配置
# ----------------------------------------------------------------------------

variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "enable_image_scanning" {
  description = "Enable vulnerability scanning on push"
  type        = bool
  default     = true
}

variable "image_retention_count" {
  description = "Number of images to retain"
  type        = number
  default     = 10

  validation {
    condition     = var.image_retention_count >= 1 && var.image_retention_count <= 100
    error_message = "Image retention count must be between 1 and 100."
  }
}

# ----------------------------------------------------------------------------
# VPC配置
# ----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# ----------------------------------------------------------------------------
# EKS集群配置
# ----------------------------------------------------------------------------

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.30"

  validation {
    condition     = can(regex("^1\\.(2[89]|30)$", var.eks_cluster_version))
    error_message = "EKS cluster version must be 1.28, 1.29, or 1.30."
  }
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.small"
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 2

  validation {
    condition     = var.eks_node_min_size >= 1 && var.eks_node_min_size <= 10
    error_message = "Node min size must be between 1 and 10."
  }
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 4

  validation {
    condition     = var.eks_node_max_size >= var.eks_node_min_size && var.eks_node_max_size <= 10
    error_message = "Node max size must be >= min size and <= 10."
  }
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2

  validation {
    condition     = var.eks_node_desired_size >= var.eks_node_min_size && var.eks_node_desired_size <= var.eks_node_max_size
    error_message = "Node desired size must be between min and max size."
  }
}

# ----------------------------------------------------------------------------
# 标签配置
# ----------------------------------------------------------------------------

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}

  # 示例：
  # additional_tags = {
  #   CostCenter = "engineering"
  #   Team       = "platform"
  # }
}

# ============================================================================
# 变量使用指南
# ============================================================================
# 
# 1. 设置变量的4种方式（优先级从高到低）：
#    
#    a. 命令行参数（最高优先级）
#       terraform apply -var="environment=production"
#    
#    b. 环境变量
#       export TF_VAR_environment=production
#       terraform apply
#    
#    c. tfvars文件
#       terraform apply -var-file="prod.tfvars"
#    
#    d. 默认值（最低优先级）
#       variable中的default值
#
# 2. 创建多环境配置文件：
#    
#    # dev.tfvars
#    environment = "dev"
#    aws_region  = "us-east-1"
#    
#    # prod.tfvars
#    environment = "production"
#    aws_region  = "us-east-1"
#    image_tag_mutability = "IMMUTABLE"
#
# 3. 变量验证：
#    - validation块确保输入值符合要求
#    - 避免无效配置导致的部署失败
#    - 提供清晰的错误消息
#
# 4. 敏感变量：
#    variable "db_password" {
#      description = "Database password"
#      type        = string
#      sensitive   = true  # 不会在日志中显示
#    }
#
# ============================================================================
