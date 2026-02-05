# Phase 3: Kubernetes容器编排 - 完整总结

> **阶段目标**：将Docker容器部署到Kubernetes，掌握容器编排的核心技能

---

## 📋 本阶段完成内容

### 1. 创建的文件

```
sre-lab/
├── k8s/
│   ├── deployment.yaml    # Deployment配置（265行，含详细注释）
│   ├── service.yaml       # Service配置（154行）
│   ├── hpa.yaml          # HPA自动扩缩容（212行）
│   └── configmap.yaml    # ConfigMap和Secret（256行）
```

### 2. 部署的资源

```
✅ Deployment: mao-quotes-api (3个副本)
✅ Service: mao-quotes-service (NodePort)
✅ HPA: mao-quotes-api-hpa (2-10副本)
✅ ConfigMap: mao-quotes-api-config
✅ Secret: mao-quotes-api-secret
```

### 3. 验证的功能

```
✅ Pod自动创建和维护
✅ 健康检查正常工作（Liveness & Readiness）
✅ 负载均衡到3个Pod
✅ 手动扩缩容（3→5→3）
✅ 查看日志和执行命令
✅ 通过NodePort访问（localhost:30080）
```

---

## 🎓 核心概念详解

### 一、Kubernetes vs Docker

#### Docker解决的问题
```
如何打包应用 → Docker镜像
如何运行应用 → Docker容器
```

#### Kubernetes解决的问题
```
如何管理大量容器？
├── 自动调度：选择合适的节点运行容器
├── 自愈：容器挂了自动重启
├── 负载均衡：流量分发到多个容器
├── 服务发现：容器间如何找到彼此
├── 自动扩缩容：根据负载调整容器数量
└── 滚动更新：不停机更新应用
```

**类比理解**：
```
Docker = 集装箱（标准化打包）
Kubernetes = 港口管理系统（自动调度、负载均衡、自愈）

Docker run = 手动搬运集装箱
Kubernetes = 自动化港口，智能调度几万个集装箱
```

---

### 二、Kubernetes核心概念（⭐⭐⭐）

#### 1. Pod - 最小部署单元

**定义**：Pod = 一组容器 + 共享存储/网络

```
┌─────────────────────────┐
│  Pod                    │
│  ┌──────────────────┐   │
│  │ Container 1      │   │
│  │ (main app)       │   │
│  └──────────────────┘   │
│  ┌──────────────────┐   │
│  │ Container 2      │   │  ← 可选（通常1个Pod=1个容器）
│  │ (sidecar)        │   │
│  └──────────────────┘   │
│                         │
│  IP: 10.244.0.5         │
│  Labels: app=myapp      │
└─────────────────────────┘
```

**关键特性**：
- 每个Pod有独立IP
- Pod内容器共享网络（localhost通信）
- Pod是临时的（随时可能被删除重建）
- Pod IP会变化（不能依赖Pod IP）

**面试问题：为什么需要Pod？为什么不直接用容器？**

**答案**：
> Pod是Kubernetes的最小调度单位，而不是容器。原因：
> 
> 1. **紧密耦合的容器需要共同调度**
>    - 应用容器 + 日志收集sidecar
>    - 应用容器 + 监控代理
>    - 必须在同一节点，共享Volume
> 
> 2. **共享资源**
>    - 共享网络命名空间（同一Pod内用localhost通信）
>    - 共享存储卷（数据交换）
>    - 共享IPC（进程间通信）
> 
> 3. **原子性**
>    - Pod作为一个整体被调度、启动、停止
>    - 不会出现"一半在这个节点，一半在那个节点"
> 
> 4. **设计模式**
>    - Sidecar：日志收集、监控
>    - Ambassador：代理本地连接到外部服务
>    - Adapter：标准化输出格式

---

#### 2. Deployment - 声明式部署

**Docker vs Kubernetes**：

| 方式 | Docker | Kubernetes |
|------|--------|------------|
| 风格 | **命令式**：告诉它怎么做 | **声明式**：告诉它想要什么 |
| 启动 | `docker run` | 写YAML，`kubectl apply` |
| 更新 | 停止→删除→启动新版本 | 自动滚动更新 |
| 扩容 | 手动启动更多容器 | 改replicas数字 |
| 自愈 | 挂了需要手动重启 | 自动重启 |

**Deployment管理的层次**：

```
Deployment
    ↓ 管理
ReplicaSet
    ↓ 管理
Pod
    ↓ 运行
Container
```

**为什么要ReplicaSet？**
```
Deployment更新时：
1. 创建新的ReplicaSet-v2
2. 逐步增加v2的副本
3. 逐步减少v1的副本
4. 保留旧的ReplicaSet（方便回滚）

回滚时：
只需要切换回旧的ReplicaSet
```

**面试问题：Deployment的滚动更新原理？**

**答案**（⭐⭐⭐ 高频）：

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # 最多多1个Pod
    maxUnavailable: 1  # 最多少1个Pod
```

**更新过程**（3个Pod，v1→v2）：

```
初始：3个v1
[v1] [v1] [v1]

步骤1：创建1个v2（maxSurge=1，总共4个）
[v1] [v1] [v1] [v2]

步骤2：v2就绪后，删除1个v1（maxUnavailable=1，总共3个）
[v1] [v1] [v2]

步骤3：创建第2个v2（总共4个）
[v1] [v1] [v2] [v2]

步骤4：删除第2个v1（总共3个）
[v1] [v2] [v2]

步骤5：创建最后1个v2（总共4个）
[v1] [v2] [v2] [v2]

完成：删除最后1个v1
[v2] [v2] [v2]
```

**关键优势**：
- **零停机**：始终有至少2个Pod运行
- **可回滚**：发现问题立即回滚到v1
- **金丝雀**：可以先更新1个验证

**常用命令**：
```bash
# 更新镜像
kubectl set image deployment/myapp app=myapp:v2

# 查看更新状态
kubectl rollout status deployment/myapp

# 查看更新历史
kubectl rollout history deployment/myapp

# 回滚
kubectl rollout undo deployment/myapp

# 回滚到指定版本
kubectl rollout undo deployment/myapp --to-revision=2
```

---

#### 3. Service - 服务发现和负载均衡

**问题**：Pod的IP会变，怎么访问？

```
Pod删除重建 → IP从10.244.0.5变成10.244.0.8
如果其他Pod硬编码了旧IP → 连接失败
```

**解决**：Service提供稳定的访问入口

```
┌──────────────────────┐
│  Service             │
│  ClusterIP: 10.96.0.1│ ← 虚拟IP（不变）
│  DNS: my-service     │ ← DNS名称（不变）
└──────────┬───────────┘
           │ 负载均衡
     ┌─────┼─────┐
     ↓     ↓     ↓
  [Pod1][Pod2][Pod3]
  10.1  10.2  10.3  ← Pod IP（会变）
```

**Service类型**（⭐⭐⭐ 面试必考）：

| 类型 | 用途 | 访问方式 | 使用场景 |
|------|------|----------|----------|
| **ClusterIP** | 集群内部 | http://service-name | 微服务间调用（默认） |
| **NodePort** | 对外暴露 | http://节点IP:30080 | 开发测试 |
| **LoadBalancer** | 云负载均衡 | 获得真实公网IP | 生产环境（AWS/GCP/Azure） |
| **ExternalName** | CNAME记录 | 返回外部域名 | 访问集群外服务 |

**我们使用的NodePort**：

```yaml
type: NodePort
ports:
- port: 80            # Service端口（集群内访问）
  targetPort: 8000    # Pod端口
  nodePort: 30080     # 节点端口（外部访问）
```

**流量路径**：
```
外部请求
  ↓
http://localhost:30080
  ↓
NodePort (30080)
  ↓
Service (port 80)
  ↓
负载均衡算法（随机/轮询）
  ↓
Pod-1, Pod-2, 或 Pod-3 (targetPort 8000)
```

**Service工作原理**（⭐⭐⭐ 深度）：

1. **创建Service时，Kubernetes做什么？**
   ```
   a. 分配ClusterIP（虚拟IP，如10.96.0.1）
   b. 创建Endpoints对象（Pod IP列表）
   c. 更新iptables/IPVS规则（实现负载均衡）
   d. 更新CoreDNS（DNS解析）
   ```

2. **Endpoints**
   ```bash
   kubectl get endpoints my-service
   # 输出：
   # 10.1.0.6:8000,10.1.0.7:8000,10.1.0.8:8000
   
   # 动态维护：
   # - Pod就绪 → 加入Endpoints
   # - Pod失败 → 从Endpoints移除（readinessProbe）
   # - Pod删除 → 从Endpoints移除
   ```

3. **负载均衡算法**
   ```
   kube-proxy模式：
   - iptables模式：随机选择（默认，性能好）
   - IPVS模式：支持多种算法（rr/lc/sh等）
   ```

4. **DNS服务发现**
   ```
   完整DNS名称：
   service-name.namespace.svc.cluster.local
   
   简化访问（同namespace）：
   http://service-name
   
   跨namespace：
   http://service-name.other-namespace
   ```

**面试加分回答**：
> "在我们项目中，Service通过Label Selector选择Pod，动态维护Endpoints。kube-proxy在每个节点上配置iptables规则，实现DNAT（目标地址转换），将Service IP转换为实际Pod IP。这样即使Pod重建IP变化，Service IP不变，实现了服务发现和负载均衡。"

---

#### 4. 健康检查 - Liveness vs Readiness（⭐⭐⭐）

**这是Phase 1的健康检查端点真正发挥作用的地方！**

```yaml
livenessProbe:   # 存活探针
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:  # 就绪探针
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 2
```

**Liveness vs Readiness对比表**（⭐⭐⭐ 必背）：

| 对比项 | Liveness（存活探针） | Readiness（就绪探针） |
|--------|---------------------|---------------------|
| **目的** | 检测容器是否还活着 | 检测容器是否准备好接收流量 |
| **失败后果** | **重启Pod** | **从Service移除，不接收流量** |
| **使用场景** | 死锁、死循环、僵尸进程 | 依赖服务不可用、缓存预热中 |
| **检查内容** | 进程是否响应 | 是否能正常处理请求 |
| **失败阈值** | 通常3次（保守） | 通常2次（敏感） |
| **恢复** | 重启后从头来 | 问题解决后自动恢复 |

**实际场景对比**：

| 场景 | Liveness | Readiness | Kubernetes行为 |
|------|----------|-----------|----------------|
| **正常运行** | ✅ PASS | ✅ PASS | 接收流量 |
| **数据库连接断了** | ✅ PASS | ❌ FAIL | 不重启，暂停流量，等DB恢复 |
| **应用死锁** | ❌ FAIL | ❌ FAIL | 重启Pod |
| **启动预热中** | ✅ PASS | ❌ FAIL | 不接收流量，等待预热完成 |
| **内存泄漏无响应** | ❌ FAIL | ❌ FAIL | 重启Pod |

**案例分析**（⭐⭐⭐ 面试常问）：

**场景1：数据库维护**
```
情况：DBA在做数据库维护，应用连接不上数据库

Liveness: PASS（进程还在运行）
Readiness: FAIL（无法处理请求）

Kubernetes行为：
- Pod不被重启（重启也没用，数据库还是连不上）
- 从Service的Endpoints移除
- 不接收新流量
- 数据库恢复后，Readiness自动PASS
- 自动加回Endpoints，恢复流量

优势：避免无意义的重启，减少故障时间
```

**场景2：应用死锁**
```
情况：某个请求导致应用死锁，无法处理任何请求

Liveness: FAIL（超时无响应）
Readiness: FAIL

Kubernetes行为：
- 连续失败3次（30秒）后重启Pod
- 重启后恢复正常
- readinessProbe通过后开始接收流量

优势：自动恢复，无需人工干预
```

**最佳实践**：

1. **initialDelaySeconds设置**
   ```yaml
   # 设置为：应用启动时间 + buffer
   FastAPI（启动快）: 10-15秒
   Spring Boot（启动慢）: 60-90秒
   机器学习模型加载：120-180秒
   
   # 太短：应用还没启动就被认为失败，反复重启
   # 太长：故障Pod长时间不被重启
   ```

2. **failureThreshold设置**
   ```yaml
   livenessProbe:
     failureThreshold: 3  # 保守（避免误杀）
   
   readinessProbe:
     failureThreshold: 2  # 敏感（快速摘流量）
   ```

3. **探针类型选择**
   ```yaml
   # HTTP探针（最常用）
   httpGet:
     path: /health
     port: 8000
   
   # TCP探针（数据库等）
   tcpSocket:
     port: 3306
   
   # 命令探针（自定义逻辑）
   exec:
     command:
     - cat
     - /tmp/healthy
   ```

---

#### 5. 资源管理 - requests vs limits（⭐⭐⭐）

```yaml
resources:
  requests:      # 保证资源（调度依据）
    memory: "256Mi"
    cpu: "250m"
  limits:        # 最大资源（硬限制）
    memory: "512Mi"
    cpu: "500m"
```

**requests vs limits对比**：

| 对比项 | requests（请求） | limits（限制） |
|--------|-----------------|---------------|
| **含义** | Pod保证能获得的资源 | Pod能使用的最大资源 |
| **调度** | **是调度依据** | 不影响调度 |
| **超卖** | 不能超卖 | 可以超卖 |
| **超限行为** | 不会超限（保证的） | CPU：限流，内存：OOM Kill |
| **设置建议** | 正常使用量（P95） | 峰值使用量（requests × 1.5-2） |

**面试问题：requests和limits的区别？为什么要分开设置？**

**答案**：

> **requests（请求）**：
> - K8s调度器选择节点时，会确保节点剩余资源 >= Pod的requests
> - 例：Node有4核CPU，已运行的Pod requests总和2核，新Pod requests 1核，可以调度（剩余3核）
> - **不能超卖**：所有Pod的requests总和不能超过节点总资源
> 
> **limits（限制）**：
> - Pod运行时可以使用的最大资源
> - CPU超限：被限流（throttled），不会被杀
> - 内存超限：OOM Kill（Out of Memory）
> - **可以超卖**：所有Pod的limits总和可以超过节点总资源
> 
> **为什么分开设置？**
> 1. **资源利用率**：大部分时间Pod不会用满limits，可以超卖
> 2. **成本优化**：如果limits=requests，需要预留大量资源，浪费
> 3. **性能保证**：requests保证最低性能，limits允许峰值
> 
> **实际设置经验**：
> - requests = 日常使用量（P95）
> - limits = 峰值使用量（requests × 1.5-2倍）
> - 观察实际使用，用`kubectl top pods`调优

**CPU单位说明**：
```
1    = 1核心 = 1000m (milli-cores)
500m = 0.5核心
100m = 0.1核心 = 10%的CPU

示例：
requests: 250m = 保证0.25核（25%）
limits: 500m = 最多0.5核（50%）
```

**内存单位说明**：
```
K/Ki: Kilobyte/Kibibyte (1024)
M/Mi: Megabyte/Mebibyte (1024^2)
G/Gi: Gigabyte/Gibibyte (1024^3)

256Mi = 256 × 1024 × 1024 bytes = 268,435,456 bytes
512Mi = 512 × 1024 × 1024 bytes = 536,870,912 bytes
```

**QoS（Quality of Service）等级**（⭐⭐⭐）：

| 等级 | 条件 | 优先级 | 资源回收顺序 |
|------|------|--------|-------------|
| **Guaranteed** | requests = limits（所有容器） | 最高 | 最后被杀 |
| **Burstable** | 至少设置了requests，requests < limits | 中等 | 中间被杀 |
| **BestEffort** | 没有设置requests/limits | 最低 | 最先被杀 |

**我们的Pod是Burstable**：
```yaml
requests: 256Mi/250m
limits: 512Mi/500m
requests < limits → Burstable
```

**QoS选择建议**：
```
Guaranteed（requests=limits）:
✅ 关键服务（数据库、核心API）
✅ 延迟敏感应用
❌ 成本高（资源利用率低）

Burstable（requests<limits）:
✅ 大部分应用（Web API、微服务） ← 推荐
✅ 平衡性能和成本
✅ 我们的项目使用这个

BestEffort（无限制）:
✅ 批处理任务
✅ 测试环境
❌ 生产环境不推荐（容易被杀）
```

**面试案例**：
> "在我们项目中，Web API使用Burstable QoS，requests设置为P95使用量（256Mi/250m），limits设置为峰值的1.5倍（512Mi/500m）。这样既保证了日常性能，又允许应对突发流量。通过Prometheus监控，我们发现实际使用量在200Mi/200m左右，峰值时达到400Mi/350m，验证了配置的合理性。"

---

#### 6. HPA (Horizontal Pod Autoscaler)

**HPA = 根据负载自动调整Pod数量**

```yaml
minReplicas: 2
maxReplicas: 10
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 70  # 目标70% CPU
```

**HPA工作原理**：

```
1. 每15秒（默认）查询metrics-server
2. 计算当前指标值
3. 计算期望副本数

公式：
期望副本数 = ceil(当前副本数 × (当前指标值 / 目标指标值))

示例：
当前：3个Pod，CPU使用率140%，目标70%
期望 = ceil(3 × (140 / 70)) = ceil(6) = 6个Pod
```

**扩缩容行为**（⭐⭐⭐）：

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60   # 扩容前观察60秒
    policies:
    - type: Percent
      value: 100  # 每次最多翻倍
    - type: Pods
      value: 2    # 或每次最多+2个
  
  scaleDown:
    stabilizationWindowSeconds: 300  # 缩容前观察300秒
    policies:
    - type: Percent
      value: 50   # 每次最多减少50%
    - type: Pods
      value: 1    # 或每次最多-1个
```

**为什么扩容快，缩容慢？**

| 方向 | 速度 | 原因 |
|------|------|------|
| **扩容** | 快（60秒） | 负载高影响用户，宁可多花钱 |
| **缩容** | 慢（300秒） | 避免频繁波动（"抖动"），节省资源不紧急 |

**面试问题：HPA vs VPA？**

**答案**：
> **HPA (Horizontal Pod Autoscaler)**：
> - 水平扩展：增加Pod数量
> - 基于CPU/内存/自定义指标
> - 适合无状态应用
> - 推荐使用（更灵活）
> 
> **VPA (Vertical Pod Autoscaler)**：
> - 垂直扩展：调整Pod的CPU/内存
> - 需要重启Pod（有停机时间）
> - 适合有状态应用（不能水平扩展）
> 
> **最佳实践**：
> - 优先使用HPA（无停机）
> - 两者不要同时使用（会冲突）

---

#### 7. ConfigMap vs Secret

**ConfigMap = 非敏感配置**
**Secret = 敏感信息**

| 对比项 | ConfigMap | Secret |
|--------|-----------|---------|
| **用途** | 环境变量、配置文件 | 密码、密钥、token |
| **编码** | 明文或Base64（可选） | Base64（必须） |
| **存储** | 明文 | 可以加密（at rest） |
| **权限** | 普通RBAC | 更严格的RBAC |
| **大小限制** | 1MB | 1MB |

**ConfigMap的4种使用方式**：

```yaml
# 方式1：单个环境变量
env:
- name: ENV
  valueFrom:
    configMapKeyRef:
      name: my-config
      key: ENV

# 方式2：所有键值对作为环境变量
envFrom:
- configMapRef:
    name: my-config

# 方式3：命令行参数
args: ["--env=$(ENV)"]

# 方式4：挂载为文件
volumeMounts:
- name: config
  mountPath: /etc/config
volumes:
- name: config
  configMap:
    name: my-config
```

**Secret注意事项**（⭐⭐⭐ 安全重要）：

1. **Base64不是加密**
   ```bash
   # 编码
   echo -n "password" | base64
   # cGFzc3dvcmQ=
   
   # 解码（任何人都能做）
   echo "cGFzc3dvcmQ=" | base64 -d
   # password
   ```

2. **真正的安全依赖**：
   - RBAC权限控制（谁能访问Secret）
   - etcd加密（at rest encryption）
   - 传输加密（TLS）

3. **生产环境更好的方案**：
   - AWS Secrets Manager
   - HashiCorp Vault
   - External Secrets Operator

---

## 🛠️ Kubernetes常用命令

### 资源查看

```bash
# 查看所有资源
kubectl get all

# 查看Deployment
kubectl get deployments
kubectl get deploy
kubectl describe deployment myapp

# 查看Pod
kubectl get pods
kubectl get po
kubectl get pods -o wide  # 显示更多信息（IP、节点）
kubectl get pods -w       # 持续监控
kubectl describe pod myapp-xxx

# 查看Service
kubectl get services
kubectl get svc
kubectl describe service myapp-service

# 查看Endpoints（重要）
kubectl get endpoints
kubectl get ep

# 查看HPA
kubectl get hpa
kubectl describe hpa myapp-hpa

# 查看ConfigMap/Secret
kubectl get configmap
kubectl get secret
kubectl describe configmap myapp-config
```

### 日志和调试

```bash
# 查看Pod日志
kubectl logs pod-name
kubectl logs pod-name -f           # 实时跟踪
kubectl logs pod-name --tail=100   # 最后100行
kubectl logs pod-name -c container-name  # 多容器时指定容器
kubectl logs -l app=myapp          # 根据标签查看所有Pod

# 进入Pod执行命令
kubectl exec -it pod-name -- /bin/bash
kubectl exec -it pod-name -- env
kubectl exec pod-name -- ps aux

# 端口转发
kubectl port-forward pod/myapp-xxx 8080:8000
kubectl port-forward service/myapp 8080:80

# 查看事件
kubectl get events
kubectl get events --sort-by='.lastTimestamp'
```

### 扩缩容和更新

```bash
# 手动扩缩容
kubectl scale deployment myapp --replicas=5

# 自动扩缩容（创建HPA）
kubectl autoscale deployment myapp --min=2 --max=10 --cpu-percent=70

# 更新镜像
kubectl set image deployment/myapp container-name=image:v2

# 滚动更新状态
kubectl rollout status deployment/myapp
kubectl rollout history deployment/myapp

# 回滚
kubectl rollout undo deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=2

# 暂停/恢复滚动更新
kubectl rollout pause deployment/myapp
kubectl rollout resume deployment/myapp
```

### 资源管理

```bash
# 创建/更新资源
kubectl apply -f deployment.yaml
kubectl apply -f k8s/  # 整个目录

# 删除资源
kubectl delete deployment myapp
kubectl delete pod myapp-xxx
kubectl delete -f deployment.yaml

# 查看资源使用（需要metrics-server）
kubectl top nodes
kubectl top pods

# 编辑资源
kubectl edit deployment myapp
kubectl edit service myapp

# 查看资源YAML
kubectl get deployment myapp -o yaml
kubectl get pod myapp-xxx -o json
```

### 标签和选择器

```bash
# 根据标签查询
kubectl get pods -l app=myapp
kubectl get pods -l app=myapp,version=v1
kubectl get pods -l 'app in (myapp,yourapp)'

# 添加标签
kubectl label pod myapp-xxx env=prod

# 删除标签
kubectl label pod myapp-xxx env-

# 查看所有标签
kubectl get pods --show-labels
```

---

## 🎯 与面试技术栈的关联

### 一、AWS EKS集成

**EKS = AWS托管的Kubernetes**

```
本地K8s（Docker Desktop） → 学习概念
    ↓
AWS EKS → 生产部署
```

**EKS vs 本地K8s的区别**：

| 特性 | 本地K8s | AWS EKS |
|------|---------|---------|
| 控制平面 | 自己管理 | AWS托管（自动升级、HA） |
| 工作节点 | 本地 | EC2实例 |
| 网络 | bridge | AWS VPC CNI |
| 存储 | hostPath | EBS、EFS |
| 负载均衡 | NodePort | AWS ALB/NLB |
| 监控 | kubectl top | CloudWatch Container Insights |
| 成本 | 免费 | $0.10/小时 + EC2成本 |

**Service类型在EKS中**：

```yaml
# LoadBalancer类型在EKS中会创建AWS NLB
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: LoadBalancer  # EKS自动创建NLB
  ports:
  - port: 80
    targetPort: 8000
```

**Ingress在EKS中**：

```yaml
# Ingress会创建AWS ALB（应用负载均衡器）
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: alb  # 使用AWS ALB
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: myapp
            port:
              number: 80
```

---

### 二、监控和日志

**CloudWatch Container Insights**：

```bash
# EKS中自动收集指标
- Pod CPU/内存使用
- 容器日志
- 网络IO
- 磁盘IO

# 查询示例（CloudWatch Logs Insights）
fields @timestamp, kubernetes.pod_name, log
| filter kubernetes.namespace_name = "default"
| filter log like /ERROR/
| sort @timestamp desc
| limit 100
```

**与Phase 1的关联**：
```
Phase 1: 实现了/health、/ready端点
    ↓
Phase 3: K8s使用这些端点做健康检查
    ↓
Phase 5: CloudWatch收集这些健康检查的指标
```

---

### 三、CI/CD集成

**Jenkins Pipeline + Kubernetes**：

```groovy
pipeline {
  agent any
  
  stages {
    stage('Build') {
      steps {
        // Phase 2: 构建Docker镜像
        sh 'docker build -t myapp:${BUILD_NUMBER} .'
      }
    }
    
    stage('Push to ECR') {
      steps {
        sh '''
          aws ecr get-login-password | docker login ...
          docker tag myapp:${BUILD_NUMBER} 123.dkr.ecr.us-east-2.amazonaws.com/myapp:${BUILD_NUMBER}
          docker push 123.dkr.ecr.us-east-2.amazonaws.com/myapp:${BUILD_NUMBER}
        '''
      }
    }
    
    stage('Deploy to K8s') {
      steps {
        // Phase 3: 更新Kubernetes Deployment
        sh '''
          kubectl set image deployment/myapp \
            app=123.dkr.ecr.us-east-2.amazonaws.com/myapp:${BUILD_NUMBER}
          kubectl rollout status deployment/myapp
        '''
      }
    }
  }
}
```

---

### 四、Helm Chart

**Helm = Kubernetes的包管理器**

```bash
# 为我们的应用创建Helm Chart
helm create mao-quotes-api

# Chart结构
mao-quotes-api/
├── Chart.yaml           # Chart元数据
├── values.yaml          # 默认配置
└── templates/
    ├── deployment.yaml  # 我们创建的Deployment
    ├── service.yaml     # 我们创建的Service
    ├── hpa.yaml         # 我们创建的HPA
    └── configmap.yaml   # 我们创建的ConfigMap

# 部署
helm install my-release ./mao-quotes-api

# 更新
helm upgrade my-release ./mao-quotes-api --set replicas=5

# 回滚
helm rollback my-release
```

**values.yaml示例**：

```yaml
replicaCount: 3

image:
  repository: 123.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api
  tag: v1
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer  # 生产环境用LoadBalancer
  port: 80

resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

---

## 🎤 面试高频问题总结

### 1. K8s架构

**问题**：描述Kubernetes的架构？

**答案**：
```
Kubernetes采用主从架构（Master-Worker）：

Control Plane（控制平面）：
├── API Server：所有组件通信的入口
├── etcd：存储集群状态（键值数据库）
├── Scheduler：决定Pod调度到哪个节点
├── Controller Manager：维护期望状态
└── Cloud Controller Manager：与云厂商集成

Worker Node（工作节点）：
├── kubelet：管理Pod生命周期
├── kube-proxy：管理网络规则（Service）
└── Container Runtime：实际运行容器（Docker/containerd）

工作流程：
1. 用户通过kubectl提交YAML
2. API Server验证并存储到etcd
3. Controller检测到新资源，创建Pod
4. Scheduler选择节点
5. kubelet在节点上运行容器
6. kube-proxy配置网络规则
```

---

### 2. Pod生命周期

**问题**：Pod的生命周期是怎样的？

**答案**：
```
1. Pending：Pod被接受，等待调度或拉取镜像
2. Running：Pod已绑定到节点，至少一个容器在运行
3. Succeeded：所有容器成功退出（批处理Job）
4. Failed：至少一个容器失败退出
5. Unknown：无法获取Pod状态

容器状态：
- Waiting：等待启动（拉取镜像、创建容器）
- Running：正在运行
- Terminated：已终止（成功或失败）

重启策略：
- Always：总是重启（默认）
- OnFailure：只在失败时重启
- Never：从不重启
```

---

### 3. Service工作原理

**问题**：Service是如何实现负载均衡的？

**答案**（⭐⭐⭐ 深度）：
```
kube-proxy的三种模式：

1. userspace模式（已废弃）
   - kube-proxy在用户空间监听端口
   - 性能差，有额外的内核态/用户态切换

2. iptables模式（默认）
   - kube-proxy配置iptables规则
   - 每个Service对应一条DNAT规则
   - 随机选择一个Pod（性能好）
   - 缺点：规则多时性能下降

3. IPVS模式（推荐）
   - 基于内核的IPVS（LVS）
   - 支持多种负载均衡算法
   - 性能更好，支持更多Service

示例（iptables模式）：
1. 创建Service（ClusterIP: 10.96.0.1）
2. kube-proxy添加iptables规则：
   -A KUBE-SERVICES -d 10.96.0.1/32 -p tcp -m tcp --dport 80 -j KUBE-SVC-XXX
3. KUBE-SVC-XXX规则随机跳转到Pod：
   -A KUBE-SVC-XXX -m statistic --mode random --probability 0.33 -j KUBE-SEP-POD1
   -A KUBE-SVC-XXX -m statistic --mode random --probability 0.50 -j KUBE-SEP-POD2
   -A KUBE-SVC-XXX -j KUBE-SEP-POD3
4. 流量被DNAT到实际Pod IP
```

---

### 4. 滚动更新详解

**问题**：如何实现零停机部署？

**答案**（⭐⭐⭐ 高频）：
```
Kubernetes通过滚动更新（Rolling Update）实现：

关键参数：
- maxSurge: 1        # 更新时最多多1个Pod
- maxUnavailable: 1  # 更新时最多1个Pod不可用

流程（3个Pod，v1→v2）：
1. 创建1个v2 Pod（总共4个，超出3个的1个就是maxSurge）
2. 等待v2 Pod就绪（readinessProbe通过）
3. 删除1个v1 Pod（总共3个）
4. 重复步骤1-3，直到全部是v2

零停机的保证：
- 始终有至少minReplicas - maxUnavailable个Pod运行
- 新Pod必须通过readinessProbe才接收流量
- 可以随时回滚

生产环境策略：
- 金丝雀部署：先更新1个Pod，观察指标
- 蓝绿部署：创建全新的Deployment，切换Service
- 分批发布：不同Region分批更新
```

---

### 5. 资源限制实战

**问题**：生产环境遇到的资源限制问题？

**答案**（STAR法则）：
```
S（情况）：
生产环境频繁出现Pod OOM（内存溢出被杀）

T（任务）：
优化资源限制，确保服务稳定

A（行动）：
1. 分析问题：
   kubectl describe pod → Last State: OOMKilled
   查看监控：内存使用接近limits (512Mi)
   
2. 调查根因：
   kubectl top pods → 实际使用600Mi
   查看应用日志：高峰期并发请求多
   
3. 短期方案：
   调整limits: 512Mi → 1Gi
   kubectl set resources deployment myapp --limits=memory=1Gi
   
4. 长期优化：
   - 分析代码内存泄漏
   - 优化缓存策略
   - 添加HPA自动扩容（分散负载）
   - requests: 512Mi, limits: 1Gi（QoS: Burstable）

R（结果）：
- OOM问题解决，3个月0事故
- 通过HPA，高峰期自动扩到8个Pod
- 内存使用稳定在400-600Mi
- 成本增加20%，但稳定性大幅提升
```

---

## 📋 复习清单

### 必须掌握（面试必考）
- [ ] Pod、Deployment、Service的概念和关系
- [ ] Liveness vs Readiness探针（必背对比表）
- [ ] requests vs limits的区别
- [ ] 滚动更新原理（画图说明）
- [ ] Service类型和使用场景
- [ ] HPA工作原理
- [ ] ConfigMap vs Secret

### 应该了解（加分项）
- [ ] Kubernetes架构（Control Plane + Worker）
- [ ] Service工作原理（kube-proxy、iptables）
- [ ] QoS等级
- [ ] Pod生命周期
- [ ] Helm Chart基础

### 可以深入（高级）
- [ ] 网络模型（CNI）
- [ ] 存储（PV、PVC、StorageClass）
- [ ] RBAC权限控制
- [ ] 自定义资源（CRD）
- [ ] Operator模式

---

## 🎯 下一步：Phase 4

**AWS云部署**
- 创建EKS集群
- 推送镜像到ECR
- 配置ALB Ingress
- 集成CloudWatch监控

---

**Phase 3 完成！✅**

你已经掌握了Kubernetes的核心技能，这是云原生架构的基础！
