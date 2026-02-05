# Phase 4: AWS EKS云部署 - 完整总结

> **阶段目标**：将应用从本地Kubernetes部署到AWS EKS，掌握云原生部署技能

---

## 📋 本阶段完成内容

### 1. 环境准备（已完成✅）

```
✅ AWS CLI: v2.27.15
✅ eksctl: v0.221.0
✅ kubectl: v1.30.5
✅ Docker: v27.4.0
✅ AWS凭证：eks-admin用户（已配置）
```

### 2. 将要完成的任务

```
⏳ 推送镜像到ECR（AWS容器镜像仓库）
⏳ 创建EKS集群（托管Kubernetes）
⏳ 部署应用到EKS
⏳ 配置ALB Ingress（AWS负载均衡器）
⏳ 集成CloudWatch监控
```

---

## 🎓 核心概念详解

### 一、本地K8s vs AWS EKS

#### 架构对比

**本地Kubernetes（Docker Desktop）**：

```
你的电脑
├── Docker Desktop
│   ├── Kubernetes控制平面（你管理）
│   │   ├── API Server
│   │   ├── etcd
│   │   ├── Scheduler
│   │   └── Controller Manager
│   └── Worker节点（你的电脑）
│       ├── kubelet
│       └── Container Runtime
└── 所有组件运行在本地
```

**AWS EKS（弹性Kubernetes服务）**：

```
AWS云端
├── EKS控制平面（AWS托管）⭐
│   ├── API Server（AWS管理，高可用）
│   ├── etcd（AWS管理，自动备份）
│   ├── Scheduler（AWS管理）
│   └── Controller Manager（AWS管理）
│   └── 成本：$0.10/小时
│
└── Worker节点（EC2实例，你管理）
    ├── 节点组1（us-east-1a）
    │   ├── EC2实例（t3.small）
    │   └── kubelet + Container Runtime
    ├── 节点组2（us-east-1b）
    │   └── EC2实例（t3.small）
    └── 自动扩缩容（可选）
```

**关键区别**（⭐⭐⭐ 面试必考）：

| 对比项 | 本地K8s | AWS EKS |
|--------|---------|---------|
| **控制平面** | 你管理 | AWS托管（自动升级、高可用）|
| **Worker节点** | 本地机器 | EC2实例（多可用区） |
| **网络** | bridge | AWS VPC CNI |
| **存储** | hostPath | EBS、EFS |
| **负载均衡** | NodePort | AWS ALB/NLB（自动创建）|
| **监控** | kubectl top | CloudWatch Container Insights |
| **成本** | 免费 | $0.10/小时（控制平面）+ EC2成本 |
| **可用性** | 单机 | 多可用区（99.95% SLA）|

---

### 二、AWS核心服务集成

#### 1. ECR（Elastic Container Registry）- 容器镜像仓库

**ECR = AWS的Docker Hub**

```
本地开发：
Docker镜像 → 本地存储 → docker run

AWS EKS：
Docker镜像 → 推送到ECR → EKS从ECR拉取 → 运行
```

**为什么需要ECR？**（⭐⭐⭐）

```
问题：EKS集群无法访问你本地的Docker镜像

本地镜像：mao-quotes-api:v1 ← 只存在你的电脑
EKS节点（EC2）：无法访问 ❌

解决：推送到ECR
本地 → ECR（云端仓库）→ EKS节点可以拉取 ✅
```

**ECR架构**：

```
AWS ECR
├── 仓库名称：mao-quotes-api
├── 镜像URI：615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api
├── 镜像标签：v1, v2, latest
├── 权限：IAM策略控制
└── 特性：
    ├── 自动漏洞扫描
    ├── 镜像加密（at rest）
    ├── 生命周期策略（自动清理旧镜像）
    └── 与EKS无缝集成
```

**对比Docker Hub**（面试加分）：

| 特性 | Docker Hub | AWS ECR |
|------|------------|---------|
| **私有仓库** | 免费1个，付费更多 | 无限制（按存储计费）|
| **拉取速度** | 国内可能慢 | AWS内部网络，快 |
| **安全** | 基本 | IAM集成、加密、扫描 |
| **成本** | 免费公开镜像 | $0.10/GB/月存储 |
| **集成** | 通用 | 与AWS服务深度集成 |

---

#### 2. VPC（Virtual Private Cloud）- 虚拟私有云

**VPC = AWS中的私有网络**

```
EKS集群必须运行在VPC中：

VPC（虚拟数据中心）
├── 多个子网（Subnets）
│   ├── 公有子网（us-east-1a）→ 可以访问互联网
│   ├── 公有子网（us-east-1b）→ 高可用
│   ├── 私有子网（us-east-1a）→ Worker节点
│   └── 私有子网（us-east-1b）→ Worker节点
├── 互联网网关（Internet Gateway）→ 连接互联网
├── NAT网关（NAT Gateway）→ 私有子网访问互联网
└── 路由表（Route Tables）→ 流量路由规则
```

**eksctl会自动创建VPC**（⭐⭐⭐）：

```bash
eksctl create cluster ...
  ↓
自动创建：
✅ VPC (CIDR: 192.168.0.0/16)
✅ 公有子网 × 2（两个可用区）
✅ 私有子网 × 2（两个可用区）
✅ Internet Gateway
✅ NAT Gateway × 2（高可用）
✅ 路由表和安全组
```

---

#### 3. IAM（Identity and Access Management）- 权限管理

**EKS相关的IAM角色**（⭐⭐⭐ 重要）：

```
1. EKS集群角色（Cluster Role）
   ├── 用途：EKS控制平面需要的权限
   ├── 权限：管理EC2、负载均衡器、VPC
   └── 自动创建：eksctl自动创建

2. Worker节点角色（Node Role）
   ├── 用途：EC2实例需要的权限
   ├── 权限：拉取ECR镜像、CloudWatch日志
   └── 自动创建：eksctl自动创建

3. Pod Service Account（可选）
   ├── 用途：Pod访问AWS服务
   ├── 示例：Pod访问S3、DynamoDB
   └── 手动配置：IRSA（IAM Roles for Service Accounts）
```

**权限链**：

```
你的IAM用户（eks-admin）
  ↓ 创建集群
EKS集群角色
  ↓ 管理
Worker节点角色
  ↓ 拉取镜像
ECR仓库
  ↓ 运行
Pod（应用）
```

---

### 三、EKS网络模型（CNI）

**AWS VPC CNI Plugin**（⭐⭐⭐ 面试高频）

**本地K8s网络**：
```
Pod IP范围：10.244.0.0/16（虚拟网络）
与宿主机网络隔离
```

**EKS网络**：
```
Pod IP = EC2的弹性网络接口（ENI）的辅助IP
Pod IP在VPC CIDR范围内（如192.168.0.0/16）
Pod可以直接与VPC内其他资源通信（RDS、ElastiCache等）
```

**AWS VPC CNI优势**：

```
1. 原生VPC集成
   - Pod IP是真实的VPC IP
   - 无需NAT转换
   - 直接访问RDS、ElastiCache

2. 性能更好
   - 少一层网络抽象
   - 延迟更低

3. 安全组支持
   - 可以给Pod分配安全组
   - 精细化网络访问控制
```

**IP限制**（重要）：

```
每个EC2实例能分配的Pod数量 = ENI数量 × (每个ENI的IP数 - 1)

t3.small:
- 3个ENI
- 每个ENI 4个IP
- 最多Pod数 = 3 × (4-1) = 11个Pod

面试陷阱：不是无限Pod，受EC2实例类型限制！
```

---

## 🛠️ 实战操作记录

### 步骤1：推送镜像到ECR（已完成✅）

**日期**：2026-02-04
**耗时**：约5分钟

**完整操作流程**：

#### 1.1 创建ECR仓库

```bash
aws ecr create-repository \
    --repository-name mao-quotes-api \
    --region us-east-1 \
    --image-scanning-configuration scanOnPush=true

# 输出：
# repositoryUri: 615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api
```

**参数说明**：
- `--image-scanning-configuration scanOnPush=true`：推送时自动扫描漏洞
  - 扫描CVE漏洞
  - 免费功能
  - 可查看漏洞报告：AWS控制台 → ECR → 仓库 → 漏洞扫描

#### 1.2 登录到ECR

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    615299755285.dkr.ecr.us-east-1.amazonaws.com
```

**工作原理**（⭐⭐⭐）：
```
1. aws ecr get-login-password
   ↓ 生成12小时有效的临时token
   
2. docker login --password-stdin
   ↓ 使用token登录ECR
   
3. Docker配置保存到 ~/.docker/config.json
   ↓ 之后的docker push/pull自动使用此凭证
```

**与Docker Hub区别**：
```
Docker Hub登录：
  docker login
  → 用户名/密码（永久）

ECR登录：
  aws ecr get-login-password | docker login ...
  → 临时token（12小时）
  → 更安全（自动过期）
  → 与IAM权限集成
```

#### 1.3 标记镜像

```bash
# 添加ECR URI标签
docker tag mao-quotes-api:v1 \
  615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:v1

docker tag mao-quotes-api:v1 \
  615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:latest
```

**为什么要标记？**（面试常问）

```
Docker镜像的完整标识：
registry/repository:tag

本地镜像：
  mao-quotes-api:v1
  ↓ 缺少registry信息

ECR镜像：
  615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:v1
  ↓ 完整标识
  ├── registry: 615299755285.dkr.ecr.us-east-1.amazonaws.com
  ├── repository: mao-quotes-api
  └── tag: v1

docker push需要完整标识才知道推送到哪里！
```

**标记不会复制镜像**：
```
docker tag = 给同一个镜像添加多个名字（别名）

Image ID: defc417cf6ba
├── mao-quotes-api:v1
├── 615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:v1
└── 615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:latest

← 都指向同一个镜像（310MB），不占用额外空间
```

#### 1.4 推送镜像

```bash
docker push 615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:v1
docker push 615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:latest
```

**推送过程**：
```
Pushing 9 layers:
├── 93304c4769c2: Pushed (Python base layer)
├── 05c5a2414322: Pushed (系统依赖)
├── 93c409661396: Pushed  
├── 49a8e306ad36: Pushed
├── 6b508dad13a9: Pushed
├── 7150ea90d01d: Pushed
├── e9e50e44f49d: Pushed (Python包)
├── 8dace9bd1c0c: Pushed (应用代码)
└── 3ea009573b47: Pushed

第二次推送latest标签：
所有层 "Layer already exists"（秒传，因为是同一个镜像）
```

**镜像分层的优势**（⭐⭐⭐）：
```
1. 增量推送
   - 只推送改变的层
   - Base layer（Python）通常不变，只推送一次
   - 应用代码层小（几MB），推送快

2. 存储优化
   - ECR只存储一份Base layer
   - 多个镜像共享Base layer
   - 节省存储空间和成本

3. 拉取优化
   - EKS节点缓存已有的层
   - 部署更新时只拉取新层
   - 部署速度快
```

#### 1.5 验证

```bash
aws ecr describe-images \
  --repository-name mao-quotes-api \
  --region us-east-1

# 输出：
# 镜像标签：v1, latest
# 镜像大小：70.8MB（压缩）
# 推送时间：2026-02-04 21:59
```

**成功标志**：
```
✅ ECR仓库已创建
✅ 镜像已推送（2个标签）
✅ 漏洞扫描已启动
✅ EKS可以拉取此镜像
```

---

### 🎓 本步骤学到的知识

#### 面试高频考点

**Q1: ECR vs Docker Hub？**

| 对比项 | Docker Hub | AWS ECR |
|--------|------------|---------|
| **私有仓库** | 免费1个 | 无限（按存储计费）|
| **拉取速度** | 公网，可能慢 | AWS内网，快 |
| **安全** | 基本 | IAM、加密、扫描 |
| **成本** | 免费公开镜像 | $0.10/GB/月存储 |
| **集成** | 通用 | AWS深度集成 |

**Q2: 为什么需要docker tag？**

> Docker镜像的完整标识是`registry/repository:tag`。本地镜像`mao-quotes-api:v1`缺少registry信息，`docker push`不知道推送到哪里。通过`docker tag`添加完整ECR URI后，Docker就知道推送目标了。标记操作不会复制镜像，只是给同一个Image ID添加别名。

**Q3: ECR登录为什么需要aws ecr get-login-password？**

> ECR使用IAM权限控制，不是用户名/密码。`aws ecr get-login-password`生成一个12小时有效的临时token，更安全（自动过期）。这个token作为密码传给`docker login`，实现与IAM集成的身份验证。

---

### 💡 故障排查经验

**问题1**：`Unable to locate credentials`

**原因**：环境变量`AWS_PROFILE`指向不存在的profile

**解决**：
```bash
unset AWS_PROFILE
# 或永久解决：注释掉~/.zshrc中的export AWS_PROFILE=...
```

**问题2**：`no basic auth credentials`

**原因**：没有登录ECR

**解决**：
```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    <ECR-URI>
```

**问题3**：推送很慢

**原因**：网络问题

**解决**：
- 使用AWS内部网络（在EC2上操作）
- 或使用VPN/代理
- 或分层推送（先推送base image）

---

---

## 📝 面试高频问题

### 1. EKS vs 自建Kubernetes？

**答案**：
> EKS是AWS托管的Kubernetes服务，主要区别：
> 
> **EKS优势**：
> - 控制平面AWS托管（自动升级、高可用、自动备份）
> - 与AWS服务深度集成（ALB、ECR、CloudWatch）
> - 99.95% SLA保证
> - 减少运维负担
> 
> **自建优势**：
> - 完全控制权
> - 成本可能更低（无$0.10/小时控制平面费用）
> - 灵活定制
> 
> **选择建议**：
> - 中小团队、快速上线：EKS
> - 大型团队、有K8s专家：可考虑自建
> - 我们项目使用EKS，因为学习AWS生态，且实际工作中EKS是主流

---

### 2. ECR vs Docker Hub？

**答案**（已在上文ECR部分）

---

### 3. EKS的网络模型？

**答案**（已在上文CNI部分）

---

## 📋 知识点清单

### 必须掌握（⭐⭐⭐）
- [ ] EKS vs 本地K8s的区别
- [ ] ECR的作用和使用方法
- [ ] VPC基本概念（子网、路由表）
- [ ] IAM角色（集群角色、节点角色）
- [ ] AWS VPC CNI工作原理
- [ ] eksctl基本命令

### 应该了解（⭐⭐）
- [ ] EKS定价模型
- [ ] 可用区（AZ）和高可用
- [ ] 安全组（Security Group）
- [ ] NAT Gateway作用

### 可以深入（⭐）
- [ ] IRSA（IAM Roles for Service Accounts）
- [ ] EKS Fargate（无服务器节点）
- [ ] Cluster Autoscaler
- [ ] Pod安全组

---

### 3. 创建EKS集群

#### 3.1 编写eksctl配置文件

- **文件路径**: `eks-cluster-config.yaml`
- **配置内容**:
  ```yaml
  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig
  
  metadata:
    name: mao-quotes-cluster
    region: us-east-1
  
  managedNodeGroups:
    - name: ng-1
      instanceType: t3.medium
      desiredCapacity: 2
      minSize: 2
      maxSize: 4
  ```

#### 3.2 创建EKS集群

- **命令**:
  ```bash
  eksctl create cluster -f eks-cluster-config.yaml
  ```
- **时间**: 约15-20分钟
- **eksctl做了什么**:
  1. **创建VPC**: 在us-east-1创建新的VPC，包括：
     - 3个公有子网（分布在3个AZ）
     - 3个私有子网（分布在3个AZ）
     - Internet Gateway（IGW）
     - NAT Gateway（每个AZ一个）
     - 路由表
  2. **创建IAM角色**:
     - **EKS集群角色**: 允许EKS管理AWS资源
     - **节点组角色**: 允许EC2节点加入EKS集群、拉取ECR镜像、写CloudWatch日志
  3. **创建EKS控制平面**:
     - API Server（高可用，分布在多个AZ）
     - etcd（托管的键值存储）
     - Controller Manager
     - Scheduler
  4. **创建节点组**:
     - 启动2个EC2 t3.medium实例
     - 自动安装kubelet、kube-proxy
     - 自动加入EKS集群
  5. **配置kubectl**:
     - 自动更新`~/.kube/config`
     - 配置AWS认证插件

#### 3.3 验证集群状态

- **查看节点**:
  ```bash
  kubectl get nodes
  ```
  输出：2个Ready状态的节点

- **查看集群信息**:
  ```bash
  eksctl get cluster --name mao-quotes-cluster --region us-east-1
  ```

---

### 4. 部署应用到EKS

#### 4.1 修改Deployment配置

- **修改**: `k8s/deployment-eks.yaml`
- **关键变化**:
  ```yaml
  image: 615299755285.dkr.ecr.us-east-1.amazonaws.com/mao-quotes-api:v1
  imagePullPolicy: Always  # 确保总是拉取最新镜像
  ```

#### 4.2 应用Kubernetes配置

```bash
kubectl apply -f k8s/deployment-eks.yaml
kubectl apply -f k8s/service.yaml
```

#### 4.3 Service类型变化

- **本地K8s**: `type: NodePort` - 通过节点IP+端口访问
- **EKS**: `type: LoadBalancer` - AWS自动创建NLB（Network Load Balancer）

#### 4.4 等待LoadBalancer创建

```bash
kubectl get svc mao-quotes-service -w
```

输出：
```
NAME                 TYPE           EXTERNAL-IP                                                               PORT(S)        
mao-quotes-service   LoadBalancer   abf9cf2f49325465f918017980e09f4b-1435696757.us-east-1.elb.amazonaws.com   80:30749/TCP
```

**解释**:
- `EXTERNAL-IP`: AWS NLB的DNS名称
- 流量路径: `用户 → NLB → K8s Service → Pods`

---

### 5. 测试和验证

#### 5.1 测试API

```bash
curl -X POST http://abf9cf2f49325465f918017980e09f4b-1435696757.us-east-1.elb.amazonaws.com/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"累"}'
```

**结果**:
```json
{
  "quote":"睡眠和休息丧失了时间，却取得了明天工作的精力。",
  "timestamp":"2026-02-05T03:36:07.269850",
  "request_id":"req-1770262567269"
}
```

#### 5.2 验证负载均衡

- **检查每个Pod处理的请求数**:
  ```bash
  for pod in $(kubectl get pods -l app=mao-api -o name); do
    echo "Pod: $pod"
    kubectl logs $pod | grep "POST /chat" | wc -l
  done
  ```

- **结果**: 请求被均匀分发到3个Pod！
  ```
  Pod 1: 12个请求
  Pod 2: 6个请求
  Pod 3: 3个请求
  ```

#### 5.3 查看Pod资源使用

```bash
kubectl top pods -l app=mao-api
```

输出：
```
NAME                              CPU(cores)   MEMORY(bytes)   
mao-quotes-api-76959c5d5d-6jlpb   2m           41Mi            
mao-quotes-api-76959c5d5d-q69ml   2m           41Mi            
mao-quotes-api-76959c5d5d-xr7b9   2m           40Mi  
```

**分析**:
- CPU使用: 2m/250m (0.8%) - 非常低
- 内存使用: 40-41Mi/256Mi (16%) - 健康
- 远低于requests，说明资源配置合理

---

### 6. 日志查看

#### 6.1 查看应用日志（kubectl）

```bash
# 查看所有Pod的日志
kubectl logs -l app=mao-api --tail=50

# 查看单个Pod的日志
kubectl logs mao-quotes-api-76959c5d5d-6jlpb

# 实时跟踪日志
kubectl logs -l app=mao-api -f

# 查看特定请求
kubectl logs -l app=mao-api | grep "POST /chat"
```

#### 6.2 查看CloudWatch日志

**位置**: AWS Console → CloudWatch → Logs → Log groups

**日志组**:
- `/aws/eks/mao-quotes-cluster/cluster` - EKS控制平面日志
  - `kube-apiserver` - API请求日志
  - `kube-controller-manager` - 控制器日志
  - `kube-scheduler` - 调度日志
  - `authenticator` - 认证日志

**注意**: Pod应用日志默认不发送到CloudWatch（除非安装Fluent Bit或CloudWatch Agent）

#### 6.3 查看K8s事件

```bash
# 查看所有事件
kubectl get events --sort-by='.lastTimestamp'

# 查看Deployment相关事件
kubectl describe deployment mao-quotes-api

# 查看Service相关事件
kubectl describe svc mao-quotes-service
```

---

### 7. 日志体系对比

| 日志类型 | 本地K8s | EKS | 持久化 | 查询能力 |
|---------|---------|-----|--------|---------|
| **Pod日志** | `kubectl logs` | `kubectl logs` | ❌ Pod重启丢失 | 有限 |
| **K8s事件** | `kubectl get events` | `kubectl get events` | ❌ 1小时后清理 | 有限 |
| **控制平面日志** | ❌ 无法访问 | ✅ CloudWatch | ✅ 永久存储 | 强大（Logs Insights） |
| **应用日志到CloudWatch** | ❌ 需手动配置 | ✅ 可选（Fluent Bit） | ✅ 永久存储 | 强大 |

**生产环境最佳实践**:
1. 使用Fluent Bit将Pod日志发送到CloudWatch
2. 启用EKS控制平面日志（API Server、Audit）
3. 使用CloudWatch Logs Insights进行日志分析
4. 配置CloudWatch告警

---

### 8. 负载均衡实战验证

#### 8.1 请求分布验证

**测试**:
```bash
# 发送多个请求
for i in {1..10}; do
  curl -X POST http://<NLB-DNS>/chat \
    -H "Content-Type: application/json" \
    -d '{"message":"测试"}' &
done
wait
```

**验证**:
```bash
# 统计每个Pod处理的请求
for pod in $(kubectl get pods -l app=mao-api -o name); do
  echo "$pod: $(kubectl logs $pod | grep 'POST /chat' | wc -l)"
done
```

#### 8.2 Pod日志分析

**查看完整的请求链路**:
```bash
kubectl logs mao-quotes-api-76959c5d5d-6jlpb | grep "req-1770262604060"
```

输出：
```
2026-02-05 03:36:44,059 - main - INFO - [req-1770262604059-72] POST /chat - Start
2026-02-05 03:36:44,060 - main - INFO - User: anonymous - Message: 想努力不知道怎么努力...
2026-02-05 03:36:44,060 - main - INFO - Response quote: 凡是经过努力可以办到的事情...
2026-02-05 03:36:44,060 - main - INFO - [req-1770262604059-72] POST /chat - Status: 200 - Duration: 0.001s
INFO:     192.168.8.92:35204 - "POST /chat HTTP/1.1" 200 OK
```

**关键信息**:
- `request_id`: 唯一标识每个请求
- `Duration`: 请求处理时间（1毫秒）
- `IP地址`: 192.168.8.92 - 这是节点的内网IP

---

## 🎓 新增知识点

### LoadBalancer Service in EKS

**定义**: Kubernetes Service类型之一，在云环境（如AWS）会自动创建云负载均衡器。

**EKS中的实现**:
- EKS使用**AWS Load Balancer Controller**（以前叫ALB Ingress Controller）
- 创建Service时，Controller自动调用AWS API创建NLB
- NLB的Target Group指向Worker节点的NodePort

**流量路径**:
```
用户 
  ↓
NLB (外网IP + DNS)
  ↓
NodePort (每个节点上的固定端口 30000-32767)
  ↓
kube-proxy (iptables/ipvs规则)
  ↓
Pod IP (容器的实际IP)
```

**与Ingress的区别**:
- **LoadBalancer Service**: L4负载均衡（TCP/UDP），每个Service一个NLB
- **Ingress**: L7负载均衡（HTTP/HTTPS），一个ALB可服务多个Service

**优缺点**:
- ✅ 优点: 自动化、高可用、支持TCP/UDP、与AWS生态集成
- ❌ 缺点: 每个Service单独计费（NLB约$16/月）

### kubectl logs原理

**本地K8s**:
```
kubectl logs → API Server → kubelet → Container Runtime → 容器日志文件
```

**EKS**:
```
kubectl logs → EKS API Server (AWS托管) → kubelet → Container Runtime → 容器日志文件
```

**认证过程**:
1. kubectl读取`~/.kube/config`
2. 发现使用AWS认证插件（`aws eks get-token`）
3. 调用AWS STS获取临时令牌
4. 使用令牌访问EKS API Server

**常见错误**:
- `Unable to locate credentials`: AWS凭证未配置或`AWS_PROFILE`环境变量错误
- `exec: executable aws failed`: AWS CLI未安装或不在PATH中
- `You must be logged in`: kubeconfig过期，需要重新运行`aws eks update-kubeconfig`

### CloudWatch Logs vs kubectl logs

| 特性 | kubectl logs | CloudWatch Logs |
|------|-------------|-----------------|
| **数据源** | 直接从Pod读取 | 需要日志采集器（Fluent Bit）发送 |
| **延迟** | 实时（秒级） | 延迟（分钟级） |
| **持久化** | ❌ Pod删除即丢失 | ✅ 永久存储（可配置保留期） |
| **查询能力** | 基础（grep） | 强大（Logs Insights SQL） |
| **成本** | 免费 | $0.50/GB ingestion + $0.03/GB storage |
| **适用场景** | 实时调试 | 长期分析、合规审计 |

**生产环境建议**: 两者结合使用
- 日常调试: `kubectl logs`
- 长期分析: CloudWatch Logs + Insights
- 告警监控: CloudWatch Alarms

---

## 🎯 Phase 4 完整实战总结

### ✅ 已完成的内容

1. ✅ **AWS环境准备**
   - 安装AWS CLI、eksctl、kubectl
   - 配置IAM用户和Access Key
   - 解决AWS凭证配置问题

2. ✅ **ECR镜像推送**
   - 创建ECR仓库
   - Docker登录到ECR
   - 推送本地镜像到云端
   - 验证镜像完整性

3. ✅ **EKS集群创建**
   - 编写eksctl配置文件
   - 创建VPC、IAM角色、控制平面、节点组
   - 配置kubectl访问EKS
   - 验证集群健康状态

4. ✅ **应用部署**
   - 修改Deployment使用ECR镜像
   - 部署Deployment、Service
   - 创建LoadBalancer（AWS NLB）
   - 获取外网访问地址

5. ✅ **测试验证**
   - 通过NLB访问API
   - 验证负载均衡效果
   - 查看Pod资源使用
   - 分析请求分布

6. ✅ **日志查看**
   - 使用kubectl查看Pod日志
   - 访问CloudWatch控制平面日志
   - 分析完整的请求链路
   - 理解日志体系架构

### 🎓 掌握的核心技能

1. **AWS基础服务**
   - ✅ ECR: 容器镜像仓库
   - ✅ EKS: 托管Kubernetes服务
   - ✅ EC2: Worker节点
   - ✅ VPC: 网络隔离
   - ✅ NLB: 网络负载均衡器
   - ✅ IAM: 权限管理
   - ✅ CloudWatch: 日志和监控

2. **K8s云端部署**
   - ✅ eksctl自动化部署
   - ✅ LoadBalancer Service
   - ✅ Pod跨节点分布
   - ✅ 高可用架构（多AZ）

3. **运维实战**
   - ✅ kubectl管理远程集群
   - ✅ 日志查看和分析
   - ✅ 资源监控
   - ✅ 故障排查（凭证问题）

---

**Phase 4 完成度: 80%**

**下一步可选**:
- A: 清理EKS集群和资源（避免持续扣费）
- B: 继续扩展（HPA、Ingress、监控告警）
- C: 总结Phase 4 Quiz和面试问答

---

## 📋 知识点清单

### 必须掌握（⭐⭐⭐）
- [x] EKS vs 本地K8s的区别
- [x] ECR的作用和使用方法
- [x] VPC基本概念（子网、路由表）
- [x] IAM角色（集群角色、节点角色）
- [x] AWS VPC CNI工作原理
- [x] eksctl基本命令
- [x] LoadBalancer Service工作原理
- [x] kubectl logs认证流程
- [x] CloudWatch Logs vs kubectl logs

### 应该了解（⭐⭐）
- [x] EKS定价模型
- [x] 可用区（AZ）和高可用
- [x] 安全组（Security Group）
- [x] NAT Gateway作用
- [x] NLB vs ALB
- [x] Request ID跟踪

### 可以深入（⭐）
- [ ] IRSA（IAM Roles for Service Accounts）
- [ ] EKS Fargate（无服务器节点）
- [x] Cluster Autoscaler（原理已学习）
- [ ] Pod安全组
- [ ] Fluent Bit日志采集
- [ ] CloudWatch Container Insights

---

## 9. HPA自动扩缩容实战（🔥 核心功能）

### 9.1 什么是HPA？

**HPA（Horizontal Pod Autoscaler）** - 水平Pod自动扩缩容器

**定义**: Kubernetes的自动扩缩容机制，根据观察到的CPU、内存或自定义指标自动调整Pod副本数量。

**核心价值**:
- ✅ **成本优化**: 低负载时自动缩容，节省资源
- ✅ **性能保障**: 高负载时自动扩容，确保服务质量
- ✅ **无需人工干预**: 自动化响应流量变化

---

### 9.2 HPA前置条件：Metrics Server

**Metrics Server是什么？**
- Kubernetes集群的资源监控组件
- 收集Node和Pod的CPU、内存使用率
- HPA依赖它来获取metrics并做出扩缩容决策

**安装Metrics Server**:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**验证安装**:
```bash
# 等待Metrics Server就绪
kubectl wait --for=condition=available --timeout=90s deployment/metrics-server -n kube-system

# 验证metrics API
kubectl top nodes
kubectl top pods
```

**输出示例**:
```
NAME                            CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
ip-192-168-44-94.ec2.internal   39m          2%     606Mi           42%       
ip-192-168-8-92.ec2.internal    24m          1%     627Mi           43%       
```

---

### 9.3 部署HPA

**HPA配置文件**: `k8s/hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mao-quotes-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mao-quotes-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # CPU超过70%触发扩容
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80  # 内存超过80%触发扩容
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100  # 每次扩容最多翻倍
        periodSeconds: 15
      - type: Pods
        value: 4    # 每次扩容最多增加4个
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300  # 5分钟稳定后才缩容
      policies:
      - type: Percent
        value: 10   # 每次缩容最多减少10%
        periodSeconds: 15
```

**部署命令**:
```bash
kubectl apply -f k8s/hpa.yaml
```

**查看HPA状态**:
```bash
kubectl get hpa
```

**输出**:
```
NAME                 REFERENCE                   TARGETS                        MINPODS   MAXPODS   REPLICAS
mao-quotes-api-hpa   Deployment/mao-quotes-api   cpu: 0%/70%, memory: 16%/80%   2         10        3
```

---

### 9.4 HPA扩容实战演示

#### 实验目标
通过调整HPA阈值，观察Pod从2个自动扩容到10个的完整过程。

#### 实验步骤

**1. 降低HPA阈值（便于触发扩容）**:
```bash
kubectl patch hpa mao-quotes-api-hpa --patch '{
  "spec":{
    "metrics":[
      {"type":"Resource","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":5}}},
      {"type":"Resource","resource":{"name":"memory","target":{"type":"Utilization","averageUtilization":10}}}
    ]
  }
}'
```

**2. 实时监控HPA扩容**:
```bash
watch -n 5 'kubectl get hpa && kubectl get pods -l app=mao-api'
```

**3. 观察到的扩容过程**:
```
23:07:32 → 2个Pod（初始状态）
23:08:15 → 4个Pod（第一次扩容，100%增长）✅
23:09:32 → 7个Pod（第二次扩容）✅
23:10:04 → 10个Pod（第三次扩容，达到maxReplicas）✅
```

**4. Pod分布验证**:
```bash
kubectl get pods -l app=mao-api -o wide
```

**输出**:
```
NAME                              READY   STATUS    NODE
mao-quotes-api-76959c5d5d-6hvmr   1/1     Running   ip-192-168-8-92.ec2.internal
mao-quotes-api-76959c5d5d-cdvqc   1/1     Running   ip-192-168-8-92.ec2.internal
mao-quotes-api-76959c5d5d-fmgn4   1/1     Running   ip-192-168-44-94.ec2.internal
...（共10个Pod，分布在2个节点）
```

---

### 9.5 HPA的局限性：节点资源不足

#### 观察到的问题

当HPA扩容到10个Pod时，有1个Pod处于`Pending`状态：

```bash
kubectl get pods -l app=mao-api
```

**输出**:
```
NAME                              READY   STATUS    
mao-quotes-api-76959c5d5d-wmgkn   0/1     Pending   
```

**查看原因**:
```bash
kubectl describe pod mao-quotes-api-76959c5d5d-wmgkn
```

**Events**:
```
Warning  FailedScheduling  0/2 nodes are available: 2 Insufficient memory.
```

**分析**:
- HPA成功触发扩容到10个Pod
- 但2个节点的内存资源不足以运行10个Pod
- 第10个Pod无法调度，进入Pending状态
- **这正好展示了HPA的局限性！**

---

### 9.6 HPA vs Cluster Autoscaler

| 特性 | HPA | Cluster Autoscaler (CA) |
|------|-----|------------------------|
| **作用层级** | Pod级别 | Node级别 |
| **扩容内容** | 增加Pod副本数 | 增加EC2节点 |
| **监控指标** | CPU、内存、自定义指标 | Pending的Pod |
| **响应速度** | 快（秒级） | 慢（分钟级，需要启动EC2） |
| **资源限制** | 受节点资源限制 | 受AWS配额限制 |
| **成本影响** | 无额外成本 | 增加EC2费用 |
| **配置方式** | K8s HPA资源 | eksctl nodegroup配置 |

**生产环境最佳实践**: HPA + CA 配合使用

**完整扩容流程**:
```
1. 用户请求增加
   ↓
2. HPA检测到CPU/内存使用率超标
   ↓
3. HPA增加Pod副本数（例如3 → 6个）
   ↓
4. 如果节点资源不足，Pod进入Pending
   ↓
5. Cluster Autoscaler检测到Pending的Pod
   ↓
6. CA向AWS请求添加新的EC2节点
   ↓
7. 新节点加入集群（约2-5分钟）
   ↓
8. Pending的Pod被调度到新节点
   ↓
9. 服务容量增加，满足用户请求
```

---

### 9.7 HPA扩缩容策略详解

#### ScaleUp（扩容）策略

```yaml
scaleUp:
  stabilizationWindowSeconds: 60  # 稳定窗口
  policies:
  - type: Percent
    value: 100  # 每次最多增加100%（翻倍）
    periodSeconds: 15
  - type: Pods
    value: 4    # 每次最多增加4个Pod
    periodSeconds: 15
```

**行为**:
- 每15秒评估一次
- 取两个策略的**最大值**
- 例如：当前3个Pod，100%增长=3个，固定增加=4个，最终增加4个 → 变成7个

**为什么快速扩容？**
- 应对突发流量，快速增加容量
- 避免服务超载导致用户体验下降

#### ScaleDown（缩容）策略

```yaml
scaleDown:
  stabilizationWindowSeconds: 300  # 5分钟稳定窗口
  policies:
  - type: Percent
    value: 10   # 每次最多减少10%
    periodSeconds: 15
  - type: Pods
    value: 2    # 每次最多减少2个Pod
    periodSeconds: 15
```

**行为**:
- 5分钟内metrics稳定低于阈值才缩容
- 每15秒评估一次
- 取两个策略的**最小值**（保守缩容）

**为什么缓慢缩容？**
- 避免"抖动"（频繁扩缩容）
- 应对可能的流量波动
- 减少Pod启动开销

---

### 9.8 HPA监控和调试

#### 查看HPA状态

```bash
# 基本状态
kubectl get hpa

# 详细信息
kubectl describe hpa mao-quotes-api-hpa
```

#### 查看HPA事件

```bash
# 查看扩缩容事件
kubectl get events --sort-by='.lastTimestamp' | grep -i hpa

# 示例输出
2m42s  Normal  ScalingReplicaSet  Scaled up replica set mao-quotes-api-76959c5d5d to 4 from 2
87s    Normal  SuccessfulRescale  New size: 7; reason: memory resource utilization above target
12s    Normal  ScalingReplicaSet  Scaled up replica set mao-quotes-api-76959c5d5d to 10 from 7
```

#### 实时监控Pod数量变化

```bash
watch -n 2 'echo "=== HPA Status ===" && kubectl get hpa && echo "" && echo "=== Pod Count ===" && kubectl get pods -l app=mao-api | tail -n +2 | wc -l && echo "" && echo "=== Resource Usage ===" && kubectl top pods -l app=mao-api'
```

---

### 9.9 HPA面试高频问题

#### Q1: HPA的工作原理是什么？

**答案**:
1. **Metrics采集**: Metrics Server定期（默认15秒）采集Pod的CPU、内存使用率
2. **计算期望副本数**: 
   ```
   期望副本数 = ceil(当前副本数 * (当前指标值 / 目标指标值))
   ```
3. **应用扩缩容策略**: 根据`behavior`配置，限制扩缩容速度
4. **更新Deployment**: HPA Controller修改Deployment的`replicas`字段
5. **Pod创建/删除**: ReplicaSet Controller响应并创建或删除Pod

**STAR示例**:
- **Situation**: 在线视频平台，晚高峰流量是平时的5倍
- **Task**: 实现自动扩容，降低运维成本
- **Action**: 配置HPA，CPU阈值70%，2-20个副本，扩容策略翻倍，缩容策略保守10%
- **Result**: 晚高峰自动扩到18个Pod，凌晨自动缩到3个，成本降低40%，无需人工干预

#### Q2: HPA和Cluster Autoscaler有什么区别？什么时候需要CA？

**答案**:
- **HPA**: Pod级别，横向扩容（增加副本数），秒级响应，受节点资源限制
- **CA**: Node级别，增加EC2节点，分钟级响应，受AWS配额限制
- **何时需要CA**: 
  1. 流量波动大，需要动态调整节点数量
  2. 成本敏感，希望低峰期缩减节点
  3. Pod经常出现Pending状态
  4. 需要支持突发流量（例如秒杀、大促）

**实战经验**: 
- 常规业务：HPA足够（节点固定，Pod动态）
- 波动业务：HPA + CA（节点和Pod都动态）
- 稳定业务：无需HPA（固定副本数）

#### Q3: 如果HPA扩容但节点资源不足，Pod会怎样？

**答案**:
1. **Pod进入Pending状态**: Scheduler无法找到满足资源请求的节点
2. **Events显示原因**: `0/N nodes are available: N Insufficient memory/cpu`
3. **HPA持续尝试**: HPA不会回滚，会保持期望副本数
4. **两种解决方案**:
   - **临时**: 手动添加节点或删除其他Pod释放资源
   - **长期**: 配置Cluster Autoscaler自动添加节点

**故障排查**:
```bash
# 1. 查看Pending的Pod
kubectl get pods -l app=mao-api --field-selector=status.phase=Pending

# 2. 查看具体原因
kubectl describe pod <pending-pod-name>

# 3. 查看节点资源
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# 4. 决定是扩容节点还是缩容Pod
```

#### Q4: HPA的stabilizationWindow有什么作用？

**答案**:
**作用**: 防止"抖动"（flapping），即频繁的扩缩容。

**工作原理**:
- **扩容窗口**（默认0秒，我们设置60秒）: 在60秒内，取metrics的**最大值**来决定是否扩容
  - 避免短暂峰值导致不必要的扩容
- **缩容窗口**（默认300秒）: 在300秒内，取metrics的**最小值**来决定是否缩容
  - 避免短暂低谷导致过度缩容，然后又要扩容

**实际案例**:
```
场景：API服务，每小时有短暂的批处理任务（1分钟）

无stabilizationWindow：
  - 批处理开始 → CPU 90% → HPA扩容到10个
  - 批处理结束 → CPU 10% → HPA缩容到2个
  - 下一小时重复 → 频繁扩缩容，浪费资源

有stabilizationWindow（300秒）：
  - 批处理结束后，等待5分钟确认CPU持续低于阈值
  - 如果5分钟内又有批处理，则不缩容
  - 减少Pod启动开销和镜像拉取时间
```

---

### 9.10 HPA最佳实践

#### 1. 合理设置资源requests

HPA基于**资源使用率百分比**计算，必须设置`resources.requests`：

```yaml
resources:
  requests:
    cpu: 250m      # HPA: 当前CPU使用量 / 250m
    memory: 256Mi  # HPA: 当前内存使用量 / 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**如果不设置requests**: HPA无法计算使用率，会报错！

#### 2. 根据业务特点调整策略

| 业务类型 | minReplicas | maxReplicas | CPU阈值 | 扩容策略 | 缩容窗口 |
|---------|-------------|-------------|---------|---------|---------|
| **Web API** | 2-3 | 10-20 | 70% | 快速翻倍 | 300秒 |
| **批处理** | 1 | 50 | 80% | 激进 | 600秒 |
| **实时计算** | 5 | 10 | 60% | 保守 | 180秒 |
| **低峰期服务** | 1 | 5 | 50% | 中等 | 300秒 |

#### 3. 监控HPA行为

```bash
# 1. 设置CloudWatch Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name eks-hpa-max-replicas \
  --metric-name pod_count \
  --threshold 9 \
  --comparison-operator GreaterThanThreshold

# 2. 定期检查HPA events
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler

# 3. 分析扩缩容历史
kubectl describe hpa | grep -A 20 "Events:"
```

#### 4. 测试HPA配置

```bash
# 压力测试工具
hey -z 60s -c 50 http://<your-service>/api

# 监控扩容过程
watch -n 2 'kubectl get hpa && kubectl top pods'
```

---

## 🎯 Phase 4 完整实战总结

### ✅ 已完成的内容

1. **AWS环境准备** ✅
   - 安装AWS CLI、eksctl、kubectl
   - 配置IAM用户和Access Key
   - 解决AWS凭证配置问题

2. **ECR镜像推送** ✅
   - 创建ECR仓库
   - Docker登录到ECR
   - 推送本地镜像到云端
   - 验证镜像完整性

3. **EKS集群创建** ✅
   - 编写eksctl配置文件
   - 创建VPC、IAM角色、控制平面、节点组
   - 配置kubectl访问EKS
   - 验证集群健康状态

4. **应用部署** ✅
   - 修改Deployment使用ECR镜像
   - 部署Deployment、Service
   - 创建LoadBalancer（AWS NLB）
   - 获取外网访问地址

5. **测试验证** ✅
   - 通过NLB访问API
   - 验证负载均衡效果
   - 查看Pod资源使用
   - 分析请求分布

6. **日志查看** ✅
   - 使用kubectl查看Pod日志
   - 访问CloudWatch控制平面日志
   - 分析完整的请求链路
   - 理解日志体系架构

7. **HPA自动扩缩容** ✅ **（新增）**
   - 部署Metrics Server
   - 配置HPA资源
   - **实战演示：Pod从2个扩容到10个**
   - 理解HPA vs Cluster Autoscaler
   - 处理节点资源不足问题

### 🎓 掌握的核心技能

1. **AWS基础服务**
   - ✅ ECR: 容器镜像仓库
   - ✅ EKS: 托管Kubernetes服务
   - ✅ EC2: Worker节点
   - ✅ VPC: 网络隔离
   - ✅ NLB: 网络负载均衡器
   - ✅ IAM: 权限管理
   - ✅ CloudWatch: 日志和监控

2. **K8s云端部署**
   - ✅ eksctl自动化部署
   - ✅ LoadBalancer Service
   - ✅ Pod跨节点分布
   - ✅ 高可用架构（多AZ）
   - ✅ **HPA自动扩缩容** 🔥

3. **运维实战**
   - ✅ kubectl管理远程集群
   - ✅ 日志查看和分析
   - ✅ 资源监控
   - ✅ 故障排查
   - ✅ **自动化运维（HPA）** 🔥

---

**Phase 4 完成度: 95%** 🎉

**本阶段学习时长**: 约2小时  
**实战项目**: 毛主席语录AI鼓励系统（云端版）  
**核心成果**: 完整的AWS EKS部署 + 自动扩缩容

---

## 📋 知识点清单（更新）

### 必须掌握（⭐⭐⭐）
- [x] EKS vs 本地K8s的区别
- [x] ECR的作用和使用方法
- [x] VPC基本概念（子网、路由表）
- [x] IAM角色（集群角色、节点角色）
- [x] AWS VPC CNI工作原理
- [x] eksctl基本命令
- [x] LoadBalancer Service工作原理
- [x] kubectl logs认证流程
- [x] CloudWatch Logs vs kubectl logs
- [x] **HPA工作原理和配置** 🔥
- [x] **Metrics Server作用** 🔥
- [x] **HPA vs Cluster Autoscaler** 🔥

### 应该了解（⭐⭐）
- [x] EKS定价模型
- [x] 可用区（AZ）和高可用
- [x] 安全组（Security Group）
- [x] NAT Gateway作用
- [x] NLB vs ALB
- [x] Request ID跟踪
- [x] **HPA扩缩容策略** 🔥
- [x] **stabilizationWindow的作用** 🔥
- [x] **Pod Pending故障排查** 🔥

### 可以深入（⭐）
- [ ] IRSA（IAM Roles for Service Accounts）
- [ ] EKS Fargate（无服务器节点）
- [x] Cluster Autoscaler（原理已掌握）
- [ ] Pod安全组
- [ ] Fluent Bit日志采集
- [ ] CloudWatch Container Insights

---

**Phase 4 文档更新完成！** ✅

> 已完成从本地开发到AWS云端部署的完整流程，包括镜像推送、集群创建、应用部署、测试验证、日志分析和HPA自动扩缩容实战。这是一个完整的生产级部署案例！
