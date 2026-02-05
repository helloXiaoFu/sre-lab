# ============================================================================
# Workspace多环境管理示例
# ============================================================================
# 展示如何使用terraform.workspace变量来管理不同环境
# ============================================================================

# ----------------------------------------------------------------------------
# Locals：根据workspace设置环境配置
# ----------------------------------------------------------------------------
locals {
  # 当前workspace名称
  workspace = terraform.workspace
  
  # 环境配置映射表
  env_config = {
    dev = {
      instance_type      = "t3.small"
      min_size          = 1
      max_size          = 3
      desired_capacity  = 2
      enable_nat_gw     = true
      single_nat_gw     = true   # dev使用单NAT Gateway节省成本
      enable_monitoring = false   # dev不启用详细监控
    }
    staging = {
      instance_type      = "t3.medium"
      min_size          = 2
      max_size          = 5
      desired_capacity  = 3
      enable_nat_gw     = true
      single_nat_gw     = false  # staging使用多NAT Gateway提高可用性
      enable_monitoring = true   # staging启用监控
    }
    prod = {
      instance_type      = "t3.large"
      min_size          = 3
      max_size          = 10
      desired_capacity  = 6
      enable_nat_gw     = true
      single_nat_gw     = false  # prod使用多NAT Gateway
      enable_monitoring = true   # prod启用详细监控
    }
  }
  
  # 获取当前环境配置
  current_env = local.env_config[local.workspace]
  
  # 资源命名（包含workspace）
  cluster_name = "${var.project_name}-${local.workspace}"
  
  # 标签（包含workspace）
  common_tags = {
    Project     = var.project_name
    Environment = local.workspace
    ManagedBy   = "terraform"
    Workspace   = terraform.workspace
  }
}

# ----------------------------------------------------------------------------
# VPC Module - 使用workspace特定配置
# ----------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "${var.project_name}-vpc-${local.workspace}"
  cidr = var.vpc_cidr
  
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 1)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 101)]
  
  # 使用workspace特定配置
  enable_nat_gateway = local.current_env.enable_nat_gw
  single_nat_gateway = local.current_env.single_nat_gw
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc-${local.workspace}"
  })
}

# ----------------------------------------------------------------------------
# EKS Module - 使用workspace特定配置
# ----------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  
  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # Managed Node Group - 使用workspace特定配置
  eks_managed_node_groups = {
    main = {
      name           = "main-node-group"
      instance_types = [local.current_env.instance_type]
      min_size       = local.current_env.min_size
      max_size       = local.current_env.max_size
      desired_size   = local.current_env.desired_capacity
      
      # 监控配置（根据环境）
      enable_monitoring = local.current_env.enable_monitoring
      
      tags = merge(local.common_tags, {
        Name = "${local.cluster_name}-node"
      })
    }
  }
  
  tags = local.common_tags
}

# ----------------------------------------------------------------------------
# 条件资源：只在prod环境创建
# ----------------------------------------------------------------------------

# 示例1：只在prod环境创建CloudWatch Alarm
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = local.workspace == "prod" ? 1 : 0  # 只在prod创建
  
  alarm_name          = "${local.cluster_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS CPU utilization"
  
  dimensions = {
    ClusterName = module.eks.cluster_name
  }
  
  tags = local.common_tags
}

# 示例2：只在prod和staging环境启用备份
resource "aws_backup_plan" "main" {
  count = contains(["prod", "staging"], local.workspace) ? 1 : 0
  
  name = "${local.cluster_name}-backup"
  
  rule {
    rule_name         = "daily_backup"
    target_vault_name = "Default"
    schedule          = "cron(0 2 * * ? *)"  # 每天凌晨2点
    
    lifecycle {
      delete_after = local.workspace == "prod" ? 90 : 30  # prod保留90天
    }
  }
  
  tags = local.common_tags
}

# ----------------------------------------------------------------------------
# Data Sources
# ----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ----------------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------------
output "workspace_info" {
  description = "Current workspace information"
  value = {
    workspace        = local.workspace
    cluster_name     = local.cluster_name
    instance_type    = local.current_env.instance_type
    min_nodes        = local.current_env.min_size
    max_nodes        = local.current_env.max_size
    desired_nodes    = local.current_env.desired_capacity
    nat_gateway_type = local.current_env.single_nat_gw ? "Single" : "Multi-AZ"
    monitoring       = local.current_env.enable_monitoring ? "Enabled" : "Disabled"
  }
}

# ============================================================================
# 使用说明
# ============================================================================
# 
# 1. 创建dev环境：
#    terraform workspace new dev
#    terraform plan
#    terraform apply
#    结果：2个t3.small节点，1个NAT Gateway，无监控
# 
# 2. 创建staging环境：
#    terraform workspace new staging
#    terraform plan
#    terraform apply
#    结果：3个t3.medium节点，3个NAT Gateway，启用监控和备份
# 
# 3. 创建prod环境：
#    terraform workspace new prod
#    terraform plan
#    terraform apply
#    结果：6个t3.large节点，3个NAT Gateway，启用监控、备份、告警
# 
# 4. 切换环境：
#    terraform workspace select dev
#    terraform plan  # 查看dev环境的当前状态
# 
# 5. 查看所有环境：
#    terraform workspace list
# 
# ============================================================================
# 最佳实践
# ============================================================================
# 
# 1. 使用Locals定义环境配置映射
#    ✅ 集中管理，易于维护
#    ✅ 类型安全
#    ✅ 可复用
# 
# 2. 使用条件表达式创建环境特定资源
#    count = local.workspace == "prod" ? 1 : 0
# 
# 3. 使用workspace命名资源
#    name = "${var.project_name}-${local.workspace}"
# 
# 4. 为每个环境打标签
#    tags = { Environment = local.workspace }
# 
# 5. Remote Backend的key也应该包含workspace
#    key = "${var.project_name}/${terraform.workspace}/terraform.tfstate"
# 
# ============================================================================
# 注意事项
# ============================================================================
# 
# 1. 不要在代码中硬编码环境名称
#    ❌ 不好：if workspace == "prod" 到处都是
#    ✅ 好：使用locals映射表
# 
# 2. 默认workspace（default）不建议使用
#    建议：创建dev/staging/prod workspace
# 
# 3. 删除workspace前先destroy资源
#    terraform destroy
#    terraform workspace select default
#    terraform workspace delete dev
# 
# 4. Workspace vs 分离的环境目录
#    Workspace适合：配置相似，只是参数不同
#    分离目录适合：配置完全不同
# 
# ============================================================================
