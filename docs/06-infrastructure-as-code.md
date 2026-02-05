# 🏗️ Phase 6: Terraform - Infrastructure as Code

## 🎯 阶段目标

用代码管理整个AWS基础设施，实现可重复、版本化、一致的基础设施部署。

**核心理念**：
> "Infrastructure as Code (IaC) - Treat infrastructure like software"  
> "Automate everything that can be automated"

---

## 📋 学习路线

1. **Terraform基础** - IaC理念、核心概念、HCL语法
2. **实战：ECR管理** - 第一个Terraform项目、State管理
3. **实战：EKS集群** - 完整的VPC+EKS基础设施
4. **高级特性** - Remote Backend、Workspace、Drift Detection

---

## ✅ 已完成内容

### 1. Infrastructure as Code (IaC) 核心理念

#### 1.1 什么是IaC？

**Infrastructure as Code (IaC)** 是一种通过代码来定义、部署和管理基础设施的实践。

**传统方式 vs IaC**：

| 维度 | 传统方式（ClickOps） | Infrastructure as Code |
|------|---------------------|------------------------|
| **创建方式** | 手动点击AWS控制台 | 编写代码（.tf文件） |
| **可重复性** | ❌ 难以复现（步骤复杂） | ✅ 完全可重复（运行代码） |
| **版本控制** | ❌ 无法追踪变更 | ✅ Git管理，可回滚 |
| **文档** | ❌ 需要单独维护 | ✅ 代码即文档 |
| **协作** | ❌ 手动交接，容易出错 | ✅ 代码审查，团队协作 |
| **测试** | ❌ 难以测试 | ✅ 可自动化测试 |
| **一致性** | ❌ Dev/Prod可能不同 | ✅ 环境完全一致 |
| **审计** | ❌ 难以追溯谁做了什么 | ✅ Git历史记录 |

---

#### 1.2 IaC的核心价值

**1. 可重复性（Repeatability）**
```
问题：手动创建EKS集群需要：
  1. 创建VPC (15分钟)
  2. 创建Subnets (10分钟)
  3. 创建Security Groups (10分钟)
  4. 创建IAM Roles (10分钟)
  5. 创建EKS集群 (15分钟)
  6. 创建Node Group (10分钟)
  总计: 70分钟，容易出错

解决方案：Terraform一键部署
  terraform apply
  → 15分钟完成，零错误
```

**2. 版本控制（Version Control）**
```
Git历史：
  commit 123: 初始EKS集群配置（t3.small节点）
  commit 456: 升级节点类型到t3.medium
  commit 789: 增加节点数量到5个

回滚：
  git checkout commit-123
  terraform apply
  → 立即恢复到初始配置
```

**3. 一致性（Consistency）**
```
问题：Dev环境是t3.small，Prod环境是t3.large
  → 测试环境和生产环境不一致
  → "在我的环境上能运行"问题

解决方案：
  terraform/
    ├─ main.tf (共享代码)
    ├─ dev.tfvars (instance_type = "t3.small")
    └─ prod.tfvars (instance_type = "t3.large")
  
  → 只有参数不同，配置逻辑完全一致
```

**4. 协作（Collaboration）**
```
团队协作流程：
  1. 创建feature分支
  2. 修改Terraform代码
  3. terraform plan → 预览变更
  4. Pull Request + Code Review
  5. 合并到main分支
  6. terraform apply → 自动部署

优势：
  ✅ 所有变更都有审查
  ✅ 避免一个人的错误影响整个团队
  ✅ 新人可以通过代码快速了解基础设施
```

**5. 自动化（Automation）**
```
场景：需要在10个AWS区域部署相同的基础设施

手动方式：
  10个区域 × 70分钟 = 700分钟 (12小时)

Terraform方式：
  for region in us-east-1 us-west-2 eu-west-1 ...; do
    terraform apply -var="region=$region"
  done
  → 150分钟 (2.5小时)，并行可更快
```

---

#### 1.3 IaC工具对比

| 工具 | Terraform | AWS CloudFormation | Pulumi | Ansible |
|------|-----------|-------------------|--------|---------|
| **厂商** | HashiCorp | AWS | Pulumi | Red Hat |
| **语言** | HCL（声明式） | JSON/YAML（声明式） | TypeScript/Python/Go（命令式） | YAML（命令式） |
| **多云支持** | ✅ 优秀（3000+providers） | ❌ 仅AWS | ✅ 良好 | ✅ 良好 |
| **学习曲线** | 中 | 中-高 | 低（熟悉编程语言） | 中 |
| **State管理** | ✅ 显式State文件 | ✅ AWS托管 | ✅ 托管或自管理 | ❌ 无State |
| **社区** | ✅ 最大 | ✅ 大（AWS生态） | ⚠️ 较小 | ✅ 大 |
| **适用场景** | 多云、大规模 | AWS专属 | 开发者友好 | 配置管理 |

**Terraform的优势**：
- ✅ **多云支持**：AWS、GCP、Azure、Kubernetes等
- ✅ **声明式语法**：描述"想要什么"，而非"如何实现"
- ✅ **模块化**：可重用的模块，社区丰富
- ✅ **强大的社区**：Terraform Registry有数千个模块
- ✅ **Plan预览**：先预览变更，再实际应用

**Terraform的劣势**：
- ❌ **学习曲线**：需要学习HCL语法
- ❌ **State管理**：需要妥善管理State文件（可通过Remote Backend解决）
- ❌ **性能**：大规模资源时，plan/apply较慢

---

### 2. Terraform核心概念

#### 2.1 核心组件

**1. Provider（提供商）**
- **定义**：与特定云平台或服务交互的插件
- **作用**：告诉Terraform如何与AWS、GCP、Kubernetes等通信

```hcl
# 配置AWS Provider
provider "aws" {
  region = "us-east-1"
  
  # 可选：使用特定profile
  profile = "default"
  
  # 可选：默认标签
  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Project     = "mao-quotes"
    }
  }
}
```

**常用Providers**：
- `aws` - Amazon Web Services
- `google` - Google Cloud Platform
- `azurerm` - Microsoft Azure
- `kubernetes` - Kubernetes
- `docker` - Docker
- `github` - GitHub

---

**2. Resource（资源）**
- **定义**：要创建和管理的基础设施组件
- **作用**：Terraform的核心，代表一个真实的云资源

```hcl
# 创建一个ECR仓库
resource "aws_ecr_repository" "mao_quotes" {
  name                 = "mao-quotes-api"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name        = "mao-quotes-api"
    Environment = "production"
  }
}
```

**Resource语法**：
```hcl
resource "<PROVIDER>_<TYPE>" "<NAME>" {
  <ARGUMENT> = <VALUE>
  ...
}

示例：
resource "aws_ecr_repository" "mao_quotes" {
  # aws - Provider
  # ecr_repository - Resource Type
  # mao_quotes - Resource Name (在Terraform中的标识符)
  
  name = "mao-quotes-api"  # 实际在AWS中的名称
}
```

---

**3. Data Source（数据源）**
- **定义**：查询已存在的资源信息
- **作用**：读取AWS中已有资源的属性，而不创建新资源

```hcl
# 查询最新的Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 使用Data Source
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux_2.id  # 引用Data Source
  instance_type = "t3.micro"
}
```

**Resource vs Data Source**：
```
Resource:
  - 创建、更新、删除资源
  - 语法: resource "aws_ecr_repository" "name" { ... }
  
Data Source:
  - 只读取，不修改
  - 语法: data "aws_ecr_repository" "name" { ... }
```

---

**4. Variable（变量）**
- **定义**：参数化配置，避免硬编码
- **作用**：实现代码复用和多环境配置

```hcl
# variables.tf
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "node_count" {
  description = "Number of EKS worker nodes"
  type        = number
  default     = 2
  
  validation {
    condition     = var.node_count >= 2 && var.node_count <= 10
    error_message = "Node count must be between 2 and 10"
  }
}

# 使用变量
resource "aws_instance" "example" {
  instance_type = var.instance_type
  
  tags = {
    Environment = var.environment
  }
}
```

**变量类型**：
```hcl
# 基础类型
variable "string_var" {
  type = string
}

variable "number_var" {
  type = number
}

variable "bool_var" {
  type = bool
}

# 集合类型
variable "list_var" {
  type = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "map_var" {
  type = map(string)
  default = {
    dev  = "t3.small"
    prod = "t3.large"
  }
}

# 对象类型
variable "object_var" {
  type = object({
    name  = string
    count = number
  })
  default = {
    name  = "example"
    count = 3
  }
}
```

---

**5. Output（输出）**
- **定义**：导出Terraform管理的资源信息
- **作用**：方便其他Terraform模块或脚本使用

```hcl
# outputs.tf
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.mao_quotes.repository_url
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
  sensitive   = false  # 设置为true可隐藏输出
}
```

**Output使用场景**：
```bash
# 1. 在命令行查看
terraform output
terraform output ecr_repository_url

# 2. 在其他脚本中使用
ECR_URL=$(terraform output -raw ecr_repository_url)
docker tag myapp:v1 $ECR_URL:v1

# 3. 在其他Terraform模块中引用
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "kubernetes_deployment" "app" {
  # 使用另一个模块的output
  cluster_endpoint = data.terraform_remote_state.infrastructure.outputs.eks_cluster_endpoint
}
```

---

**6. Module（模块）**
- **定义**：可重用的Terraform配置的容器
- **作用**：实现代码组织和复用

```hcl
# 调用VPC模块
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  
  name = "mao-quotes-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  
  tags = {
    Environment = "production"
  }
}

# 使用模块的输出
resource "aws_eks_cluster" "main" {
  vpc_config {
    subnet_ids = module.vpc.private_subnets  # 引用模块输出
  }
}
```

---

#### 2.2 State文件（⭐⭐⭐ 核心概念）

**什么是State？**

**Terraform State** 是一个JSON文件（`terraform.tfstate`），记录了Terraform管理的所有资源的当前状态。

**为什么需要State？**

```
问题：Terraform如何知道AWS中哪些资源是它创建的？

示例：
  1. 运行 terraform apply
     → 创建了一个EKS集群

  2. 你在AWS控制台手动修改了集群配置

  3. 再次运行 terraform apply
     → Terraform如何知道集群已存在？
     → Terraform如何知道哪些配置被手动修改了？

答案：通过State文件！
```

**State文件的作用**：

1. **映射关系**：
   ```
   Terraform代码         →  State文件   →  AWS真实资源
   ────────────────        ──────────      ────────────────
   resource "aws_eks_    →  cluster_id  →  真实的EKS集群
   cluster" "main"          = "abc123"     (ID: abc123)
   ```

2. **性能优化**：
   ```
   无State：每次都要查询AWS获取所有资源信息（慢）
   有State：直接读取本地文件（快）
   ```

3. **依赖关系追踪**：
   ```
   State记录了资源之间的依赖关系：
   VPC → Subnets → Security Groups → EKS Cluster
   ```

4. **并发控制**：
   ```
   State Locking（后面会讲）：
   防止多人同时运行 terraform apply 导致冲突
   ```

---

**State文件示例**（简化版）：

```json
{
  "version": 4,
  "terraform_version": "1.6.0",
  "resources": [
    {
      "type": "aws_ecr_repository",
      "name": "mao_quotes",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "attributes": {
            "arn": "arn:aws:ecr:us-east-1:123456789:repository/mao-quotes-api",
            "name": "mao-quotes-api",
            "repository_url": "123456789.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api"
          }
        }
      ]
    }
  ]
}
```

---

**State管理最佳实践**：

**1. 永远不要手动编辑State文件**
```
❌ 错误：直接编辑 terraform.tfstate
   → 容易破坏State一致性
   → 导致Terraform无法正常工作

✅ 正确：使用Terraform命令管理State
   terraform state list
   terraform state show <resource>
   terraform state rm <resource>
   terraform state mv <old> <new>
```

**2. 将State文件加入.gitignore**
```bash
# .gitignore
*.tfstate
*.tfstate.*
.terraform/
```

**原因**：
- ❌ State文件包含敏感信息（密码、密钥）
- ❌ State文件会频繁变化，产生大量Git冲突
- ✅ 应该使用Remote Backend（后面会讲）

**3. 使用Remote Backend（推荐）**
```hcl
# 将State存储在S3 + DynamoDB
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "mao-quotes/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

**优势**：
- ✅ 团队共享State
- ✅ State加密存储
- ✅ State Locking（防止并发修改）
- ✅ 版本控制（S3 versioning）

---

### 3. HCL语法基础

**HCL (HashiCorp Configuration Language)** 是Terraform使用的声明式配置语言。

#### 3.1 基础语法

**1. Blocks（块）**

```hcl
# Block语法
<BLOCK_TYPE> "<BLOCK_LABEL>" "<BLOCK_LABEL>" {
  <ARGUMENT> = <VALUE>
  
  <NESTED_BLOCK> {
    <ARGUMENT> = <VALUE>
  }
}

# 示例
resource "aws_ecr_repository" "mao_quotes" {
  name = "mao-quotes-api"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}
```

**2. Arguments（参数）**

```hcl
# 字符串
name = "mao-quotes-api"

# 数字
port = 8080

# 布尔值
enabled = true

# 列表
availability_zones = ["us-east-1a", "us-east-1b"]

# 映射
tags = {
  Environment = "production"
  Team        = "platform"
}
```

**3. 注释**

```hcl
# 单行注释

// 也是单行注释

/*
  多行注释
  可以跨越多行
*/
```

---

#### 3.2 表达式和函数

**1. 引用（References）**

```hcl
# 引用变量
var.environment
var.instance_type

# 引用资源属性
aws_ecr_repository.mao_quotes.repository_url

# 引用模块输出
module.vpc.vpc_id

# 引用Data Source
data.aws_ami.amazon_linux_2.id
```

**2. 字符串插值**

```hcl
# 基础插值
name = "eks-cluster-${var.environment}"
# 结果: "eks-cluster-production"

# 复杂插值
description = "EKS cluster for ${var.project_name} in ${var.region}"
# 结果: "EKS cluster for mao-quotes in us-east-1"

# 引用资源属性
ecr_url = "${aws_ecr_repository.mao_quotes.repository_url}:latest"
# 结果: "123456789.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:latest"
```

**3. 条件表达式**

```hcl
# 三元运算符
instance_type = var.environment == "production" ? "t3.large" : "t3.small"

# 复杂条件
node_count = var.environment == "production" ? 5 : (var.environment == "staging" ? 3 : 1)

# 在resource中使用
resource "aws_eks_node_group" "main" {
  instance_types = var.environment == "production" ? ["t3.large"] : ["t3.small"]
}
```

**4. 常用函数**

```hcl
# 字符串函数
upper("hello")           # "HELLO"
lower("HELLO")           # "hello"
title("hello world")     # "Hello World"
format("eks-%s", var.env) # "eks-production"

# 列表函数
length(["a", "b", "c"])       # 3
concat(["a"], ["b", "c"])     # ["a", "b", "c"]
element(["a", "b", "c"], 0)   # "a"
slice(["a", "b", "c"], 0, 2)  # ["a", "b"]

# 映射函数
keys({a = 1, b = 2})          # ["a", "b"]
values({a = 1, b = 2})        # [1, 2]
lookup({a = 1, b = 2}, "a")   # 1

# 文件函数
file("path/to/file.txt")      # 读取文件内容
filebase64("file.zip")        # Base64编码
templatefile("template.tpl", {var = value})  # 模板渲染

# CIDR函数（网络计算）
cidrsubnet("10.0.0.0/16", 8, 1)  # "10.0.1.0/24"
cidrhost("10.0.0.0/24", 5)       # "10.0.0.5"
```

**实战示例**：

```hcl
# 为3个AZ创建子网
locals {
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = local.azs[count.index]
  
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# 结果：
# private-subnet-1: 10.0.0.0/24 in us-east-1a
# private-subnet-2: 10.0.1.0/24 in us-east-1b
# private-subnet-3: 10.0.2.0/24 in us-east-1c
```

---

#### 3.3 Meta-Arguments（元参数）

**1. count（循环）**

```hcl
# 创建3个相同的资源
resource "aws_subnet" "example" {
  count      = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index)
  
  tags = {
    Name = "subnet-${count.index}"
  }
}

# 引用：
# aws_subnet.example[0].id
# aws_subnet.example[1].id
# aws_subnet.example[2].id
```

**2. for_each（遍历）**

```hcl
# 使用map
variable "users" {
  type = map(string)
  default = {
    alice = "admin"
    bob   = "developer"
  }
}

resource "aws_iam_user" "example" {
  for_each = var.users
  name     = each.key
  
  tags = {
    Role = each.value
  }
}

# 引用：
# aws_iam_user.example["alice"].arn
# aws_iam_user.example["bob"].arn
```

**count vs for_each**：
```
count:
  ✅ 简单，适合创建多个相同资源
  ❌ 删除中间元素会导致所有后续资源重建
  
for_each:
  ✅ 使用key标识，删除不影响其他资源
  ✅ 更灵活，可以遍历map或set
  ❌ 稍微复杂一些
  
推荐：大多数情况使用 for_each
```

**3. depends_on（依赖）**

```hcl
# 显式声明依赖关系
resource "aws_eks_cluster" "main" {
  name = "my-cluster"
  # ...
}

resource "aws_eks_node_group" "main" {
  cluster_name = aws_eks_cluster.main.name
  
  # 确保IAM策略完全生效后再创建Node Group
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
  ]
}
```

**4. lifecycle（生命周期）**

```hcl
resource "aws_eks_cluster" "main" {
  name = "my-cluster"
  
  lifecycle {
    # 创建新资源后再删除旧资源（避免停机）
    create_before_destroy = true
    
    # 阻止资源被删除
    prevent_destroy = false
    
    # 忽略某些属性的变化
    ignore_changes = [
      tags["LastModified"],
    ]
  }
}
```

---

### 4. Terraform工作流

#### 4.1 核心命令

**完整工作流**：

```
编写代码 → init → validate → plan → apply → destroy
```

---

**1. terraform init（初始化）**

**作用**：
- 下载Provider插件
- 初始化Backend
- 下载Module

```bash
terraform init

# 输出示例：
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...
Terraform has been successfully initialized!
```

**何时运行**：
- ✅ 第一次使用Terraform项目
- ✅ 添加了新的Provider
- ✅ 修改了Backend配置

---

**2. terraform validate（验证）**

**作用**：检查配置文件语法是否正确

```bash
terraform validate

# 成功：
Success! The configuration is valid.

# 失败：
Error: Invalid expression
  on main.tf line 10, in resource "aws_instance" "example":
  10:   instance_type = var.instance_type
```

---

**3. terraform plan（计划）**

**作用**：预览将要执行的变更，**不会**实际修改基础设施

```bash
terraform plan

# 输出示例：
Terraform will perform the following actions:

  # aws_ecr_repository.mao_quotes will be created
  + resource "aws_ecr_repository" "mao_quotes" {
      + arn                  = (known after apply)
      + name                 = "mao-quotes-api"
      + registry_id          = (known after apply)
      + repository_url       = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

**符号含义**：
```
+ create  (创建新资源)
~ update  (修改现有资源)
- destroy (删除资源)
-/+ destroy and recreate (先删除再创建)
<= read   (读取Data Source)
```

**plan的重要性**：
```
❌ 危险：直接运行 terraform apply
   → 不知道会创建/修改/删除什么
   → 可能意外删除生产资源

✅ 安全：先运行 terraform plan
   → 预览所有变更
   → 确认无误后再apply
```

---

**4. terraform apply（应用）**

**作用**：实际执行变更，创建/修改/删除资源

```bash
terraform apply

# Terraform会先显示plan，然后询问确认：
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

# 执行中：
aws_ecr_repository.mao_quotes: Creating...
aws_ecr_repository.mao_quotes: Creation complete after 3s [id=mao-quotes-api]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
ecr_repository_url = "123456789.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api"
```

**自动批准**（谨慎使用）：
```bash
terraform apply -auto-approve
```

---

**5. terraform destroy（销毁）**

**作用**：删除Terraform管理的所有资源

```bash
terraform destroy

# 询问确认：
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

# 执行中：
aws_ecr_repository.mao_quotes: Destroying... [id=mao-quotes-api]
aws_ecr_repository.mao_quotes: Destruction complete after 2s

Destroy complete! Resources: 1 destroyed.
```

**部分销毁**：
```bash
# 只删除特定资源
terraform destroy -target=aws_ecr_repository.mao_quotes
```

---

**其他常用命令**：

```bash
# 格式化代码
terraform fmt

# 查看资源列表
terraform state list

# 查看特定资源详情
terraform state show aws_ecr_repository.mao_quotes

# 查看输出
terraform output
terraform output ecr_repository_url

# 刷新State（同步AWS实际状态）
terraform refresh

# 导入现有资源
terraform import aws_ecr_repository.mao_quotes mao-quotes-api

# 解除资源管理（从State中移除，但不删除实际资源）
terraform state rm aws_ecr_repository.mao_quotes
```

---

#### 4.2 工作流最佳实践

**1. 开发流程**：

```bash
# 1. 编写或修改.tf文件
vim main.tf

# 2. 格式化代码
terraform fmt

# 3. 验证语法
terraform validate

# 4. 预览变更
terraform plan

# 5. 如果plan看起来正确，应用变更
terraform apply

# 6. 查看输出
terraform output
```

**2. 团队协作流程**：

```bash
# 1. 创建feature分支
git checkout -b feature/add-eks-cluster

# 2. 编写Terraform代码
vim main.tf

# 3. 本地测试
terraform init
terraform plan

# 4. 提交代码
git add .
git commit -m "Add EKS cluster configuration"
git push origin feature/add-eks-cluster

# 5. 创建Pull Request
# 6. Code Review
# 7. 合并到main分支
# 8. CI/CD自动执行 terraform apply
```

**3. 生产环境流程**：

```bash
# 1. 使用Workspace隔离环境
terraform workspace new production
terraform workspace select production

# 2. 使用tfvars文件管理环境配置
terraform plan -var-file="environments/production.tfvars"

# 3. 应用变更
terraform apply -var-file="environments/production.tfvars"

# 4. 如果出错，快速回滚
git revert <commit-hash>
terraform apply -var-file="environments/production.tfvars"
```

---

## 📦 子阶段3：实战 - 用Terraform创建完整EKS集群 ✅

**学习时间**：2小时  
**难度**：⭐⭐⭐⭐⭐  
**完成状态**：✅ 已完成

### 目标

使用Terraform一键创建完整的企业级EKS集群，包括VPC、子网、NAT Gateway、EKS Control Plane、Worker Nodes等所有资源。

### 实战步骤

#### 1. 创建EKS Terraform配置

**文件：`terraform/eks.tf`**

创建包含以下内容的完整EKS配置：

- **VPC模块**（使用官方Module）
- **EKS模块**（使用官方Module）
- **Network配置**（3个公有子网 + 3个私有子网，跨3个AZ）

**关键配置点**：

```hcl
# 使用官方VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "${var.project_name}-vpc-${var.environment}"
  cidr = var.vpc_cidr
  
  # 跨3个AZ
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  
  # 私有子网（EKS节点）
  private_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2),
    cidrsubnet(var.vpc_cidr, 8, 3),
  ]
  
  # 公有子网（Load Balancer）
  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 101),
    cidrsubnet(var.vpc_cidr, 8, 102),
    cidrsubnet(var.vpc_cidr, 8, 103),
  ]
  
  # NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "dev" ? true : false
}

# 使用官方EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  
  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.eks_cluster_version
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      instance_types = [var.eks_node_instance_type]
      min_size       = var.eks_node_min_size
      max_size       = var.eks_node_max_size
      desired_size   = var.eks_node_desired_size
    }
  }
}
```

#### 2. 更新Variables和Outputs

**添加VPC变量**：
- `vpc_cidr`: VPC CIDR块
- `eks_cluster_version`: Kubernetes版本
- `eks_node_instance_type`: 节点实例类型
- `eks_node_min_size/max_size/desired_size`: 节点数量配置

**添加Outputs**：
- VPC ID、CIDR、子网列表
- EKS集群名称、端点、版本
- kubectl配置命令

#### 3. 执行Terraform工作流

```bash
# 1. 重新初始化（下载VPC和EKS模块）
terraform init -upgrade

# 2. 验证配置
terraform validate

# 3. 预览变化（60个资源）
terraform plan

# 4. 创建资源（15-20分钟）
terraform apply -auto-approve

# 5. 查看输出
terraform output
```

**创建的资源统计**：
- **VPC网络资源**：1个VPC + 6个子网 + 1个IGW + 1个NAT + 路由表
- **EKS集群**：1个Control Plane + 2个Worker Nodes
- **安全资源**：Security Groups + IAM Roles
- **其他**：CloudWatch Log Group、EKS Addons
- **总计**：60个资源

#### 4. 观察资源创建过程

**创建耗时统计**：
- VPC和网络：~2分钟
- EKS Control Plane：~10分51秒  
- Node Group：~1分48秒
- EKS Addons：~45秒
- **总计**：约15分钟

**AWS控制台变化对比**：

| 资源类型 | 创建前 | 创建后 | 变化说明 |
|---------|--------|--------|----------|
| VPC | 1个（默认） | 2个 | +1个（10.0.0.0/16） |
| Subnets | 6个（默认） | 12个 | +6个（3公有+3私有，跨3AZ） |
| NAT Gateway | 0个 | 1个 | 用于私有子网出站访问 |
| EKS Clusters | 0个 ❌ | 1个 ✅ | ACTIVE状态 |
| EC2 Instances | 0个 ❌ | 2个 ✅ | t3.small，分布在2个AZ |

#### 5. 验证集群状态

```bash
# 配置kubectl
aws eks update-kubeconfig --region us-east-1 --name mao-quotes-api-dev

# 查看节点
kubectl get nodes -o wide

# 查看系统Pod
kubectl get pods -n kube-system

# 查看集群信息
kubectl cluster-info
```

**或使用AWS CLI验证**：

```bash
# 查看集群状态
aws eks describe-cluster --name mao-quotes-api-dev --region us-east-1

# 查看节点组
aws eks list-nodegroups --cluster-name mao-quotes-api-dev --region us-east-1

# 查看EC2实例
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Name,Values=*mao-quotes*" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]'
```

#### 6. 部署应用到EKS

```bash
# 1. 推送Docker镜像到ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api-dev

docker tag mao-quotes-api:v1 \
  615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api-dev:v1

docker push \
  615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api-dev:v1

# 2. 部署应用
kubectl apply -f k8s/deployment-eks.yaml

# 3. 查看部署
kubectl get pods
kubectl get svc
```

#### 7. 清理资源

```bash
# 1. 删除ECR镜像（必须先做）
aws ecr batch-delete-image \
  --repository-name mao-quotes-api-dev \
  --region us-east-1 \
  --image-ids imageTag=v1

# 2. 运行terraform destroy
terraform destroy -auto-approve

# 验证清理
aws eks list-clusters --region us-east-1
aws ec2 describe-vpcs --region us-east-1
```

**清理后状态**：
- EKS集群：0个 ✅
- EC2实例：0个 ✅  
- NAT Gateway：0个 ✅
- VPC：回到1个（默认VPC） ✅
- **费用已停止计费** 💰

### 关键知识点

#### 1. Terraform Module的威力

**官方Module vs 自己写**：

| 对比项 | 自己写 | 使用官方Module |
|--------|--------|---------------|
| 代码量 | 500+ 行 | 50 行 |
| 最佳实践 | 需要自己研究 | 已内置 |
| 维护成本 | 高 | 低（社区维护） |
| Bug风险 | 高 | 低（经过验证） |
| 学习曲线 | 陡峭 | 平缓 |

**使用Module的好处**：
```hcl
# 不需要写这些：
# - aws_vpc
# - aws_subnet
# - aws_internet_gateway
# - aws_nat_gateway
# - aws_route_table
# - aws_route_table_association
# - aws_eks_cluster
# - aws_iam_role
# - aws_security_group
# - ... 等50+个资源

# 只需要：
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  # 简单配置
}
```

#### 2. VPC网络架构最佳实践

**为什么需要公有+私有子网？**
- **公有子网**：对外服务（Load Balancer）
- **私有子网**：内部服务（EKS节点、数据库）
- **安全性**：工作节点不直接暴露到互联网

**为什么跨3个AZ？**
- 高可用性：1-2个AZ故障不影响服务
- AWS SLA保证：多AZ可获得更高的SLA
- 生产环境标准：符合Well-Architected Framework

**为什么需要NAT Gateway？**
- 私有子网的实例需要访问互联网（下载包、更新）
- 但不希望被互联网直接访问
- NAT Gateway提供单向出站访问

**网络架构图**：

```
┌────────────────────────────────────────────────────────┐
│ VPC (10.0.0.0/16) - Terraform管理                     │
│                                                        │
│  【公有子网 - 3个AZ】                                  │
│  ┌─────────────────────────────────────┐              │
│  │ us-east-1a: 10.0.101.0/24           │              │
│  │ us-east-1b: 10.0.102.0/24           │ ← IGW        │
│  │ us-east-1c: 10.0.103.0/24           │              │
│  │  • Load Balancer可用                │              │
│  └─────────────────────────────────────┘              │
│                    ↓ NAT Gateway                       │
│  【私有子网 - 3个AZ】                                  │
│  ┌─────────────────────────────────────┐              │
│  │ us-east-1a: 10.0.1.0/24             │              │
│  │   ├─ EKS Node 1 (t3.small) ☸️        │              │
│  │ us-east-1b: 10.0.2.0/24             │              │
│  │   ├─ EKS Node 2 (t3.small) ☸️        │              │
│  │ us-east-1c: 10.0.3.0/24             │              │
│  │   └─ (预留，可扩展)                 │              │
│  └─────────────────────────────────────┘              │
└────────────────────────────────────────────────────────┘
```

#### 3. EKS架构理解

**EKS Control Plane（AWS管理）**：
- API Server
- Scheduler
- Controller Manager
- etcd（存储集群状态）
- **你不需要管理这些组件** ⭐

**EKS Data Plane（你管理）**：
- Worker Nodes（EC2实例）
- 运行你的Pod
- 需要管理节点数量、类型、更新

**EKS Managed Node Group的好处**：
✅ 自动创建和注册节点  
✅ 自动更新节点AMI  
✅ 自动处理节点健康检查  
✅ 与Auto Scaling集成

#### 4. 成本分析与优化

**当前配置的成本**：
- EKS Control Plane: $0.10/小时 ($72/月)
- 2个t3.small节点: $0.0416/小时 ($30/月)
- NAT Gateway: $0.045/小时 ($32.4/月)
- **总计**：约$134/月

**优化策略**：
1. **dev环境使用single NAT Gateway**（已应用，节省~$30/月）
2. **使用Spot Instances**（节省70%）
3. **开发环境下班后自动停机**
4. **使用Fargate代替EC2**（按需付费）
5. **合理设置Resource Limits**（避免过度配置）

#### 5. Terraform vs 手动操作

| 对比项 | 手动操作（Phase 4） | Terraform（Phase 6） |
|--------|-------------------|---------------------|
| 创建时间 | 30分钟（人工操作） | 15分钟（自动化） |
| 配置保存 | 分散，难以重现 | 代码化，完全可重复 |
| 团队协作 | 困难 | 简单（Git管理） |
| 变更预览 | 无 | `terraform plan` |
| 状态管理 | 手动跟踪 | `terraform.tfstate` |
| 回滚能力 | 困难 | `git revert` + `terraform apply` |
| 审计追踪 | 无 | Git commit history |

### 常见问题

#### Q1: terraform apply失败怎么办？

```bash
# 1. 查看错误信息
terraform apply

# 2. 如果是权限问题
aws sts get-caller-identity  # 验证身份

# 3. 如果是资源冲突
terraform state list  # 查看现有资源
terraform state rm <resource>  # 移除冲突资源

# 4. 重新运行
terraform apply
```

#### Q2: terraform destroy失败（ECR仓库不为空）？

```bash
# 1. 删除ECR镜像
aws ecr list-images --repository-name mao-quotes-api-dev --region us-east-1
aws ecr batch-delete-image \
  --repository-name mao-quotes-api-dev \
  --image-ids imageDigest=<digest>

# 2. 重新运行destroy
terraform destroy -auto-approve
```

#### Q3: kubectl无法连接EKS？

```bash
# 1. 检查AWS凭证
aws sts get-caller-identity

# 2. 重新配置kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name mao-quotes-api-dev

# 3. 测试连接
kubectl get nodes
```

#### Q4: 如何修改已有资源？

```bash
# 1. 修改.tf文件
vim terraform/eks.tf

# 2. 预览变化
terraform plan

# 3. 应用变化
terraform apply

# Terraform会自动计算diff并只更新变化的部分
```

### 面试题

#### Q1: 解释Terraform的Module是什么？为什么使用Module？

**参考答案**：

Module是Terraform的代码复用单元，类似于编程中的函数或类。

**为什么使用Module**：
1. **代码复用**：避免重复编写相同的配置
2. **最佳实践**：官方Module已包含行业最佳实践
3. **降低复杂度**：隐藏实现细节，只暴露必要参数
4. **提高可维护性**：集中管理，统一更新
5. **团队协作**：标准化基础设施配置

**实际例子**：
```hcl
# 不使用Module：需要写50+个资源
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "public_1" { ... }
resource "aws_subnet" "public_2" { ... }
# ... 省略45个资源

# 使用Module：10行搞定
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "my-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}
```

#### Q2: 如何确保Terraform代码的质量和安全性？

**参考答案**：

**1. 代码质量保证**：
- `terraform fmt`：格式化代码
- `terraform validate`：语法验证
- `terraform plan`：变更预览
- TFLint：静态代码分析
- Checkov：安全扫描

**2. 安全实践**：
- 使用变量而非硬编码敏感信息
- 启用加密（EBS、S3、RDS）
- 配置最小权限IAM策略
- 使用Remote Backend加密状态文件
- 定期审计terraform state

**3. 团队协作**：
- Git分支策略（feature分支）
- Code Review流程
- CI/CD自动化（自动运行plan）
- 生产环境需要人工approve

**4. 监控和告警**：
- Terraform Cloud/Enterprise
- CloudWatch Events监控资源变化
- Config Rules检查合规性

#### Q3: 如果Terraform状态文件丢失或损坏怎么办？

**参考答案**：

**预防措施**（最重要）：
1. **使用Remote Backend**：S3 + DynamoDB锁定
2. **启用S3版本控制**：可以回滚到历史版本
3. **定期备份**：`terraform state pull > backup.tfstate`
4. **使用Terraform Cloud**：自动版本管理和备份

**如果已经丢失**：
1. **从S3版本历史恢复**：
```bash
aws s3api list-object-versions \
  --bucket my-terraform-state \
  --prefix terraform.tfstate

aws s3api get-object \
  --bucket my-terraform-state \
  --key terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate
```

2. **导入现有资源**：
```bash
# 手动导入每个资源
terraform import aws_vpc.main vpc-12345
terraform import aws_subnet.private[0] subnet-67890
# ... 依次导入所有资源
```

3. **重新创建（最后手段）**：
- 如果是开发环境，可以`terraform destroy`后重新`apply`
- 生产环境需要非常谨慎

### 学习收获

通过这个子阶段，你已经掌握：

✅ **Terraform Module**：使用官方Module简化配置  
✅ **VPC网络架构**：公有/私有子网、NAT Gateway、多AZ高可用  
✅ **EKS集群管理**：Control Plane vs Data Plane、Managed Node Group  
✅ **IaC完整流程**：init → plan → apply → destroy  
✅ **资源依赖管理**：Terraform自动处理创建/删除顺序  
✅ **成本优化策略**：NAT Gateway优化、实例类型选择  
✅ **问题排查能力**：ECR清理、kubectl配置、权限问题

---

## 🚀 下一步

✅ **子阶段1已完成**：Terraform基础理论  
✅ **子阶段2已完成**：实战 - 用Terraform管理ECR  
✅ **子阶段3已完成**：实战 - 用Terraform创建EKS集群  

⏳ **子阶段4待学习**：高级特性（Remote Backend + Workspace）

---

**Phase 6 持续更新中...**

> 已完成：IaC理念、Terraform核心概念、HCL语法、工作流程、ECR管理、EKS集群创建与销毁