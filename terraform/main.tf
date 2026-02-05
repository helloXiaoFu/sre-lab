# ============================================================================
# Terraform Configuration for Mao Quotes API
# ============================================================================
# 用途：使用Terraform管理AWS基础设施
# 阶段：Phase 6 - 子阶段2 - ECR仓库管理
# ============================================================================

# ----------------------------------------------------------------------------
# Terraform Settings（Terraform配置）
# ----------------------------------------------------------------------------
terraform {
  # 指定Terraform版本要求
  required_version = ">= 1.0"

  # 指定Provider版本要求
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Provider来源
      version = "~> 5.0"        # 使用5.x版本（兼容补丁更新）
    }
  }
}

# ----------------------------------------------------------------------------
# Provider Configuration（Provider配置）
# ----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region # 从变量读取区域

  # 默认标签：所有资源都会自动添加这些标签
  default_tags {
    tags = {
      Project     = "mao-quotes-api"
      ManagedBy   = "terraform"
      Environment = var.environment
      Owner       = "sre-team"
    }
  }
}

# ----------------------------------------------------------------------------
# ECR Repository（ECR仓库）
# ----------------------------------------------------------------------------
resource "aws_ecr_repository" "mao_quotes" {
  # ECR仓库名称
  name = "${var.project_name}-${var.environment}"

  # 镜像标签可变性
  # MUTABLE: 允许覆盖同名标签（开发环境推荐）
  # IMMUTABLE: 不允许覆盖（生产环境推荐）
  image_tag_mutability = var.environment == "production" ? "IMMUTABLE" : "MUTABLE"

  # 镜像扫描配置
  image_scanning_configuration {
    scan_on_push = true # 推送镜像时自动扫描漏洞
  }

  # 加密配置
  encryption_configuration {
    encryption_type = "AES256" # 使用AES256加密（免费）
    # kms_key = var.kms_key_id  # 如果需要使用KMS加密（付费）
  }

  # 资源标签（会与default_tags合并）
  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Description = "Docker image repository for Mao Quotes API"
  }
}

# ----------------------------------------------------------------------------
# ECR Lifecycle Policy（生命周期策略）
# ----------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "mao_quotes" {
  repository = aws_ecr_repository.mao_quotes.name

  # 生命周期策略：自动清理旧镜像，节省存储费用
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"] # 只保留v开头的标签（例如v1.0.0）
          countType     = "imageCountMoreThan"
          countNumber   = 10 # 保留最新的10个镜像
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 dev/staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "staging"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7 # 未打标签的镜像7天后删除
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ----------------------------------------------------------------------------
# ECR Repository Policy（仓库策略）
# ----------------------------------------------------------------------------
# 可选：配置ECR访问权限（例如允许其他AWS账号拉取镜像）
# resource "aws_ecr_repository_policy" "mao_quotes" {
#   repository = aws_ecr_repository.mao_quotes.name
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowPull"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::另一个账号ID:root"
#         }
#         Action = [
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:BatchCheckLayerAvailability"
#         ]
#       }
#     ]
#   })
# }

# ============================================================================
# 关键概念说明
# ============================================================================
# 1. Resource命名：
#    - Terraform中: aws_ecr_repository.mao_quotes
#    - AWS中实际名称: ${var.project_name}-${var.environment}
#    
# 2. 标签继承：
#    - default_tags: 所有资源自动添加
#    - resource tags: 特定资源的额外标签
#    - 最终标签 = default_tags + resource tags
#
# 3. 生命周期策略：
#    - 规则按rulePriority顺序执行
#    - 规则1优先级最高
#    - 可设置基于标签、数量、时间的清理规则
#
# 4. 镜像扫描：
#    - scan_on_push: 自动扫描安全漏洞
#    - 扫描结果可在AWS控制台查看
#    - 可设置CI/CD在发现高危漏洞时阻止部署
# ============================================================================
