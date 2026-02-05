# ============================================================================
# EKS Cluster Configuration
# ============================================================================
# 用途：使用Terraform创建完整的EKS集群（包括VPC、EKS、Node Group）
# 架构：使用官方Module实现最佳实践
# ============================================================================

# ----------------------------------------------------------------------------
# 数据源：获取可用区列表
# ----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ----------------------------------------------------------------------------
# VPC Module（使用官方Module）
# ----------------------------------------------------------------------------
# 官方VPC Module: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc-${var.environment}"
  cidr = var.vpc_cidr

  # 使用前3个可用区
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # 私有子网（用于EKS节点）
  private_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 1),  # 10.0.1.0/24
    cidrsubnet(var.vpc_cidr, 8, 2),  # 10.0.2.0/24
    cidrsubnet(var.vpc_cidr, 8, 3),  # 10.0.3.0/24
  ]

  # 公有子网（用于Load Balancer）
  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 101), # 10.0.101.0/24
    cidrsubnet(var.vpc_cidr, 8, 102), # 10.0.102.0/24
    cidrsubnet(var.vpc_cidr, 8, 103), # 10.0.103.0/24
  ]

  # 启用NAT Gateway（允许私有子网访问互联网）
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "dev" ? true : false # dev环境使用单个NAT Gateway节省费用

  # 启用DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS需要的标签
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                    = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                           = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }

  tags = {
    Name        = "${var.project_name}-vpc-${var.environment}"
    Environment = var.environment
  }
}

# ----------------------------------------------------------------------------
# EKS Module（使用官方Module）
# ----------------------------------------------------------------------------
# 官方EKS Module: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.eks_cluster_version

  # 集群端点访问控制
  cluster_endpoint_public_access  = true  # 允许公网访问（开发环境）
  cluster_endpoint_private_access = true  # 允许VPC内访问

  # VPC配置
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # 启用IRSA（IAM Roles for Service Accounts）
  enable_irsa = true

  # 集群附加组件
  cluster_addons = {
    # CoreDNS
    coredns = {
      most_recent = true
    }
    # kube-proxy
    kube-proxy = {
      most_recent = true
    }
    # VPC CNI（网络插件）
    vpc-cni = {
      most_recent = true
    }
  }

  # EKS Managed Node Group
  eks_managed_node_groups = {
    # 主Node Group
    main = {
      name = "main-node-group"

      # 实例类型
      instance_types = [var.eks_node_instance_type]

      # 节点数量
      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      # 磁盘大小
      disk_size = 20 # GB

      # 使用最新的EKS优化AMI
      ami_type = "AL2_x86_64"

      # 标签
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      # 节点标签（用于Pod调度）
      tags = {
        Name        = "${var.project_name}-node-${var.environment}"
        Environment = var.environment
        NodeGroup   = "main"
      }
    }
  }

  # 集群标签
  tags = {
    Name        = "${var.project_name}-eks-${var.environment}"
    Environment = var.environment
  }
}

# ============================================================================
# 核心概念说明
# ============================================================================
# 
# 1. Module（模块）：
#    - terraform-aws-modules/vpc/aws: 官方VPC模块
#    - terraform-aws-modules/eks/aws: 官方EKS模块
#    - 优势：经过社区验证、遵循最佳实践、省去大量配置
#
# 2. VPC网络架构：
#    - CIDR: 10.0.0.0/16 (65536个IP)
#    - 3个公有子网: 10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24
#    - 3个私有子网: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
#    - NAT Gateway: 私有子网通过NAT访问互联网
#
# 3. EKS集群端点：
#    - Public Access: 允许kubectl从本地访问
#    - Private Access: 允许节点和Pod访问Control Plane
#
# 4. Node Group：
#    - Managed Node Group: AWS自动管理节点生命周期
#    - 自动处理更新、补丁、扩缩容
#
# 5. 成本优化：
#    - dev环境使用single_nat_gateway（节省~$30/月）
#    - 使用t3.small实例（$0.02/小时）
#    - min_size=2确保高可用，但不过度配置
#
# ============================================================================
