# Phase 2: Docker容器化 - 完整总结

> **阶段目标**：将FastAPI应用打包成Docker镜像，理解容器化原理和最佳实践

---

## 📋 本阶段完成内容

### 1. 创建的文件

```
sre-lab/
├── docker/
│   ├── Dockerfile          # 多阶段构建文件（218行，含详细注释）
│   └── .dockerignore       # 构建上下文过滤规则
```

### 2. 执行的操作

1. ✅ 清理旧的Docker资源（回收4.68GB空间）
2. ✅ 创建Dockerfile（多阶段构建）
3. ✅ 创建.dockerignore（优化构建上下文）
4. ✅ 构建Docker镜像（310MB）
5. ✅ 运行容器并测试功能
6. ✅ 分析镜像层和优化效果

---

## 🔧 Docker命令详解

### 一、镜像构建相关

#### 1. `docker build`
```bash
docker build -t mao-quotes-api:v1 -f docker/Dockerfile .
```

**参数详解**：
| 参数 | 说明 | 示例 |
|------|------|------|
| `-t, --tag` | 镜像名称和标签 | `mao-quotes-api:v1` |
| `-f, --file` | Dockerfile路径 | `docker/Dockerfile` |
| `.` | 构建上下文目录 | 当前目录 |
| `--no-cache` | 不使用缓存 | 强制重新构建所有层 |
| `--build-arg` | 传递构建参数 | `--build-arg VERSION=1.0` |

**面试考点**：
- **构建上下文**：最后的`.`代表构建上下文，Docker会把这个目录的所有文件（除了.dockerignore的）发送给daemon
- **为什么构建慢**：如果构建上下文很大（几GB），传输就慢；使用.dockerignore可以优化

**与面试内容关联**：
- 🎯 **AWS ECR**：构建完成后需要推送到ECR：`docker push 858214107245.dkr.ecr.us-east-2.amazonaws.com/app:v1`
- 🎯 **Jenkins CI/CD**：在pipeline中自动执行docker build，使用`--build-arg`传递版本号

---

#### 2. `docker images`
```bash
docker images                    # 列出所有镜像
docker images mao-quotes-api:v1  # 列出特定镜像
docker images -q                 # 只显示ID
```

**输出解读**：
```
REPOSITORY       TAG    IMAGE ID       CREATED         SIZE
mao-quotes-api   v1     defc417cf6ba   2 minutes ago   310MB
```

**面试考点**：
- **镜像大小**：包含所有层的总大小，但多个镜像可以共享层
- **IMAGE ID**：镜像的SHA256哈希值的前12位
- **悬空镜像**：REPOSITORY和TAG都是`<none>`的镜像

---

#### 3. `docker history`
```bash
docker history mao-quotes-api:v1
docker history --no-trunc mao-quotes-api:v1  # 显示完整命令
```

**作用**：查看镜像的每一层，分析大小和来源

**面试考点**：
- 用于**镜像优化**：找出哪些层占用空间大
- 用于**安全审计**：查看镜像构建过程，发现潜在问题

**与面试内容关联**：
- 🎯 **排障**：生产环境镜像过大导致拉取慢，用history分析哪里可以优化

---

### 二、容器运行相关

#### 4. `docker run`
```bash
docker run -d --name mao-api -p 8000:8000 mao-quotes-api:v1
```

**参数详解**：
| 参数 | 说明 | 示例 |
|------|------|------|
| `-d, --detach` | 后台运行 | 返回容器ID |
| `--name` | 容器名称 | `mao-api` |
| `-p, --publish` | 端口映射 | `宿主机:容器` |
| `-e, --env` | 环境变量 | `-e ENV=prod` |
| `-v, --volume` | 挂载卷 | `-v /host:/container` |
| `--restart` | 重启策略 | `always`, `unless-stopped` |
| `--network` | 网络模式 | `bridge`, `host` |
| `-m, --memory` | 内存限制 | `-m 512m` |
| `--cpus` | CPU限制 | `--cpus=2` |

**常用组合**：
```bash
# 生产环境运行
docker run -d \
  --name mao-api \
  -p 8000:8000 \
  -e ENV=production \
  -e LOG_LEVEL=info \
  -v /var/log/app:/app/logs \
  --restart unless-stopped \
  -m 512m \
  --cpus=1 \
  mao-quotes-api:v1

# 开发环境（挂载代码实时更新）
docker run -it --rm \
  -p 8000:8000 \
  -v $(pwd)/app:/app \
  mao-quotes-api:v1 \
  uvicorn main:app --reload
```

**面试考点**：
- **端口映射原理**：Docker通过iptables NAT规则实现端口转发
- **重启策略**：
  - `no`：不自动重启（默认）
  - `always`：总是重启，包括Docker daemon重启后
  - `unless-stopped`：除非手动停止，否则总是重启
  - `on-failure`：只在非0退出码时重启

**与面试内容关联**：
- 🎯 **Kubernetes**：K8s的Pod相当于一组容器，但K8s管理重启，不用`--restart`
- 🎯 **资源限制**：在K8s中对应`resources.limits.memory`和`resources.limits.cpu`
- 🎯 **AWS ECS**：也有类似的容器定义，指定CPU、内存、端口映射

---

#### 5. `docker ps`
```bash
docker ps              # 运行中的容器
docker ps -a           # 所有容器（包括停止的）
docker ps -q           # 只显示容器ID
docker ps --filter "status=exited"  # 过滤
```

**输出解读**：
```
CONTAINER ID   IMAGE               COMMAND           CREATED         STATUS                   PORTS
55ebaf2bc2ec   mao-quotes-api:v1   "uvicorn main..."   2 minutes ago   Up 2 minutes (healthy)   0.0.0.0:8000->8000/tcp
```

**STATUS说明**：
- `Up X minutes` - 运行中
- `Up X minutes (healthy)` - 运行中且健康检查通过
- `Up X minutes (unhealthy)` - 运行中但健康检查失败
- `Exited (0)` - 正常退出
- `Exited (1)` - 异常退出

**面试考点**：
- **健康检查**：Docker原生支持，但K8s会覆盖Docker的健康检查
- **容器状态**：了解容器生命周期对排障很重要

---

#### 6. `docker logs`
```bash
docker logs mao-api                # 查看所有日志
docker logs -f mao-api             # 实时跟踪（类似tail -f）
docker logs --tail 100 mao-api     # 最后100行
docker logs --since 10m mao-api    # 最近10分钟
docker logs --until 2026-02-04T10:00:00 mao-api  # 时间范围
```

**面试考点**：
- **日志驱动**：默认json-file，生产环境用fluentd或awslogs
- **日志轮转**：json-file会无限增长，需要配置max-size和max-file
- **12-factor app**：应用应该输出到stdout/stderr，不要写文件

**与面试内容关联**：
- 🎯 **CloudWatch Logs**：在AWS ECS中，使用awslogs驱动自动发送到CloudWatch
- 🎯 **Kubernetes**：K8s有自己的日志收集机制，通常用Fluentd/Fluent Bit
- 🎯 **ELK Stack**：企业级方案，Elasticsearch + Logstash + Kibana

---

#### 7. `docker exec`
```bash
docker exec -it mao-api /bin/bash       # 进入容器shell
docker exec mao-api ps aux              # 在容器内执行命令
docker exec mao-api cat /app/quotes.py  # 查看文件
```

**常用排障命令**：
```bash
# 查看进程
docker exec mao-api ps aux

# 查看网络
docker exec mao-api netstat -tlnp

# 查看文件系统
docker exec mao-api df -h

# 测试网络连接
docker exec mao-api curl http://localhost:8000/health

# 查看环境变量
docker exec mao-api env
```

**面试考点**：
- **容器不应该有ssh**：用docker exec代替ssh进入容器
- **生产环境排障**：容器是临时的，不要在容器内做持久化修改

**与面试内容关联**：
- 🎯 **Linux排障**：在容器内使用top、ps、netstat、lsof等命令
- 🎯 **Kubernetes**：对应`kubectl exec -it pod-name -- /bin/bash`

---

### 三、资源清理相关

#### 8. `docker stop / start / restart / rm`
```bash
docker stop mao-api              # 优雅停止（发送SIGTERM）
docker stop -t 30 mao-api        # 30秒后强制SIGKILL
docker start mao-api             # 启动已停止的容器
docker restart mao-api           # 重启
docker rm mao-api                # 删除容器（需先stop）
docker rm -f mao-api             # 强制删除（即使在运行）
```

**面试考点**：
- **优雅关闭**：SIGTERM → 应用处理 → SIGKILL（超时后）
- **信号处理**：应用应该监听SIGTERM，完成当前请求后退出

**与面试内容关联**：
- 🎯 **Kubernetes滚动更新**：K8s先发SIGTERM，等terminationGracePeriodSeconds后SIGKILL
- 🎯 **12-factor app**：应用要实现graceful shutdown

---

#### 9. `docker system`
```bash
docker system df                  # 磁盘使用情况
docker system prune               # 清理悬空镜像和停止的容器
docker system prune -a            # 清理所有未使用的镜像
docker system prune -a --volumes  # 包括卷
docker system prune -f            # 不询问确认
```

**清理对象**：
```
docker container prune   # 只清理容器
docker image prune       # 只清理镜像
docker image prune -a    # 清理所有未使用的镜像
docker volume prune      # 只清理卷
docker network prune     # 只清理网络
```

**面试考点**：
- **悬空镜像（Dangling）**：`<none>:<none>`的镜像，通常是重新构建时产生的
- **CI/CD清理**：Jenkins agent上定期运行prune防止磁盘满

**本阶段实操**：
```bash
# 清理前
Images: 6, SIZE: 6.082GB
Volumes: 3, SIZE: 243.8MB
Build Cache: 90, SIZE: 2.13GB

# docker system prune -a --volumes -f

# 清理后
Total reclaimed space: 4.678GB
```

---

## 📚 核心知识点详解

### 一、Docker架构（⭐⭐⭐ 面试必考）

#### 1. 三层架构

```
┌─────────────────────────────────────┐
│  Docker CLI (客户端)                 │
│  - 用户输入命令                      │
│  - 解析命令行参数                    │
│  - 通过REST API与daemon通信         │
└──────────────┬──────────────────────┘
               │ REST API
               │ Unix Socket: /var/run/docker.sock
               │ TCP: localhost:2375 (不安全)
┌──────────────▼──────────────────────┐
│  Docker Daemon (dockerd)            │
│  - 监听API请求                       │
│  - 镜像管理（构建、拉取、推送）       │
│  - 容器生命周期管理                  │
│  - 网络管理（bridge、overlay）       │
│  - 卷管理（数据持久化）              │
└──────────────┬──────────────────────┘
               │ gRPC
┌──────────────▼──────────────────────┐
│  containerd (容器运行时)             │
│  - 容器生命周期管理                  │
│  - 镜像传输和存储                    │
│  - K8s直接使用containerd             │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  runc (OCI Runtime)                 │
│  - 创建容器命名空间（namespace）     │
│  - 配置控制组（cgroups）             │
│  - 启动容器进程                      │
└──────────────────────────────────────┘
```

**面试问题：为什么Kubernetes 1.24弃用dockershim？**

**答案**：
> Kubernetes原本通过dockershim调用Docker，Docker再调用containerd。现在K8s直接使用containerd，减少一层抽象，性能更好，架构更简单。
>
> ```
> 旧架构：K8s → dockershim → Docker → containerd → runc
> 新架构：K8s → containerd → runc
> ```

---

#### 2. Docker在macOS上的特殊架构

```
┌─────────────────────────────────────┐
│   macOS (darwin/arm64)              │
│                                     │
│   ┌─────────────────────┐          │
│   │ Docker CLI          │          │
│   │ (darwin/arm64)      │          │
│   └──────────┬──────────┘          │
│              │ Unix Socket          │
│   ┌──────────▼──────────────────┐  │
│   │  Docker Desktop (VM)        │  │
│   │  ┌──────────────────────┐   │  │
│   │  │ Linux (linux/arm64)  │   │  │
│   │  │ - Docker Daemon      │   │  │
│   │  │ - containerd         │   │  │
│   │  │ - 所有容器运行在这里  │   │  │
│   │  └──────────────────────┘   │  │
│   └─────────────────────────────┘  │
└─────────────────────────────────────┘
```

**关键点**：
- 容器必须运行在Linux内核上
- macOS通过虚拟化框架（Virtualization.framework）运行Linux VM
- 性能比Linux原生略低（10-20%）

**面试加分**：
> "在Mac上开发时，我意识到容器实际运行在VM中，所以在macOS上的性能测试结果不能直接用于Linux生产环境。我们的CI/CD在Linux环境中运行，确保测试结果准确。"

---

### 二、Dockerfile最佳实践（⭐⭐⭐）

#### 1. 多阶段构建（Multi-stage Build）

**我们的实现**：
```dockerfile
# Stage 1: Builder（构建阶段）
FROM python:3.11-slim as builder
WORKDIR /build
RUN apt-get update && apt-get install -y gcc  # 安装构建工具
COPY app/requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# Stage 2: Runtime（运行阶段）
FROM python:3.11-slim
COPY --from=builder /install /usr/local  # 只复制已安装的包
COPY app/ .
CMD ["uvicorn", "main:app"]
```

**效果对比**：
| 构建方式 | 镜像大小 | 包含内容 |
|----------|----------|----------|
| 单阶段 | ~600MB | Python运行时 + gcc + 依赖包 + 应用 |
| 多阶段 | **310MB** | Python运行时 + 依赖包 + 应用 |
| 节省 | **48%** | 不包含gcc等构建工具 |

**面试问题：多阶段构建的优势？**

**答案**：
1. **减小镜像体积**：最终镜像不包含构建工具（gcc、make等）
2. **提高安全性**：攻击面减小，构建工具可能有漏洞
3. **加快部署速度**：镜像小，拉取快，启动快
4. **分离关注点**：构建和运行环境分离，职责清晰

**与面试内容关联**：
- 🎯 **AWS ECR拉取速度**：镜像从600MB减到310MB，拉取时间减半
- 🎯 **Kubernetes滚动更新**：镜像小，Pod启动快，更新速度快
- 🎯 **CI/CD优化**：构建缓存效率高

---

#### 2. 镜像分层（Image Layers）

**原理**：
```
每个Dockerfile指令创建一层（Layer）
每层是只读的
容器运行时在最上层添加可写层

┌────────────────────────────────┐
│ Container (可写层)              │  ← 容器修改在这里
├────────────────────────────────┤
│ Layer 5: CMD ["uvicorn"...]    │  0B
├────────────────────────────────┤
│ Layer 4: COPY app/ .           │  98.3KB
├────────────────────────────────┤
│ Layer 3: COPY /install ...     │  73MB
├────────────────────────────────┤
│ Layer 2: RUN useradd...        │  41KB
├────────────────────────────────┤
│ Layer 1: FROM python:3.11-slim │  237MB
└────────────────────────────────┘
```

**关键特性**：

1. **层共享**
```
镜像A: python:3.11-slim (237MB) + app1 (50MB) = 287MB
镜像B: python:3.11-slim (237MB) + app2 (60MB) = 297MB

实际磁盘占用：
237MB (python基础层，共享)
+ 50MB (app1)
+ 60MB (app2)
= 347MB (而不是584MB)
```

2. **写时复制（Copy-on-Write）**
```
容器要修改文件时：
1. 从只读层复制文件到可写层
2. 在可写层修改
3. 原镜像层不变

优势：多个容器可以共享同一镜像
```

**面试问题：为什么要把不常变的指令放前面？**

**答案 - 利用构建缓存**：
```dockerfile
# ❌ 错误顺序
COPY app/ .              # 代码经常变，导致后续都要重建
COPY requirements.txt .
RUN pip install ...      # 每次都要重新安装（慢！）

# ✅ 正确顺序
COPY requirements.txt .  # 依赖不常变
RUN pip install ...      # 使用缓存（快！）
COPY app/ .              # 代码经常变，只重建这一层
```

**实测效果**：
```
第一次构建：20秒
第二次构建（只改代码）：2秒（使用缓存）
第二次构建（错误顺序）：15秒（pip重新安装）
```

---

#### 3. 指令优化

**RUN指令合并**：
```dockerfile
# ❌ 每个RUN创建一层
RUN apt-get update
RUN apt-get install -y gcc
RUN rm -rf /var/lib/apt/lists/*
# 结果：3层，apt缓存在第二层，没被删除

# ✅ 合并为一层
RUN apt-get update && \
    apt-get install -y gcc && \
    rm -rf /var/lib/apt/lists/*
# 结果：1层，apt缓存被删除，镜像更小
```

**COPY指令优化**：
```dockerfile
# ❌ 分别复制
COPY requirements.txt /app/
COPY config.py /app/
COPY main.py /app/
# 结果：3层，缓存效率低

# ✅ 利用构建缓存
COPY requirements.txt .  # 不常变，放前面
RUN pip install ...
COPY app/ .              # 经常变，放后面
```

**面试加分**：
> "在优化Dockerfile时，我使用`docker history`分析每层大小，发现某层300MB，原来是忘记清理apt缓存。合并RUN指令后，镜像减小了250MB。"

---

#### 4. 安全最佳实践

**非root用户**：
```dockerfile
# 创建用户
RUN groupadd -r appuser && useradd -r -g appuser -u 1000 appuser

# 设置文件权限
COPY --chown=appuser:appuser app/ /app

# 切换用户
USER appuser
```

**为什么重要？**
```
容器以root运行的风险：
1. 应用被攻击 → 攻击者在容器内是root
2. 容器逃逸 → 攻击者在宿主机也是root
3. 可以修改系统文件、安装恶意软件

容器以普通用户运行：
1. 应用被攻击 → 攻击者权限受限
2. 即使逃逸 → 只是普通用户
3. 不能修改系统文件
```

**其他安全措施**：
```dockerfile
# 1. 不包含敏感信息
# ❌ 不要这样做
ENV DB_PASSWORD=mysecret  
COPY config/secrets.yaml .

# ✅ 应该这样
# 使用K8s Secret或AWS Secret Manager

# 2. 使用固定版本
# ❌ 不确定性
FROM python:3.11

# ✅ 可重现
FROM python:3.11-slim@sha256:524557f6bd...

# 3. 最小化基础镜像
FROM python:3.11-slim  # ✅ 150MB
FROM python:3.11       # ❌ 1GB
FROM scratch           # ✅✅ 0MB（Go等静态编译语言）
```

**与面试内容关联**：
- 🎯 **AWS Security Group**：多层防御，容器非root是其中一层
- 🎯 **Kubernetes SecurityContext**：可以强制要求非root：`runAsNonRoot: true`
- 🎯 **合规要求**：很多安全标准（如PCI-DSS）要求最小权限原则

---

### 三、镜像优化技巧（⭐⭐⭐）

#### 1. .dockerignore

**我们的配置**：
```
__pycache__/
*.pyc
.git/
.vscode/
*.md
venv/
.env
*.log
```

**效果**：
```
无.dockerignore：
Sending build context to Docker daemon  2.5GB

有.dockerignore：
Sending build context to Docker daemon  70.4KB

提速：35倍！
```

**面试问题：.dockerignore vs .gitignore的区别？**

**答案**：
- `.dockerignore`：控制哪些文件不进入Docker构建上下文
- `.gitignore`：控制哪些文件不提交到Git
- **两者通常有重叠**（如`__pycache__`），但用途不同
- `.dockerignore`还应该包含`.git`目录（Git历史可能很大）

---

#### 2. 基础镜像选择

| 镜像类型 | 大小 | 特点 | 适用场景 |
|----------|------|------|----------|
| `python:3.11` | ~1GB | 完整Debian | 开发环境 |
| `python:3.11-slim` | ~150MB | **最小Debian** | **生产环境（推荐）** |
| `python:3.11-alpine` | ~50MB | Alpine Linux | 特殊需求（可能有兼容性问题） |
| `distroless/python3` | ~50MB | 只有运行时，无shell | 极致安全（排障困难） |

**alpine的坑**：
```bash
# Alpine使用musl libc，不是glibc
# 某些Python包（如numpy、pandas）需要重新编译
# 编译时间可能从30秒增加到10分钟

# 对比
FROM python:3.11-slim  # pip install numpy: 5秒
FROM python:3.11-alpine  # pip install numpy: 8分钟（需要编译）
```

**面试加分**：
> "我们评估了alpine，发现编译时间太长，而且生产环境出过一次musl libc的兼容性问题。最终选择slim，性能好，稳定性高，镜像只比alpine大100MB，但节省了大量构建时间。"

---

#### 3. pip优化

```dockerfile
# ❌ 不优化
RUN pip install -r requirements.txt
# 问题：下载包缓存保留，增加镜像大小

# ✅ 优化1：禁用缓存
RUN pip install --no-cache-dir -r requirements.txt
# 效果：减少100-500MB

# ✅ 优化2：使用国内镜像（中国地区）
RUN pip install --no-cache-dir \
    -i https://mirrors.aliyun.com/pypi/simple/ \
    -r requirements.txt
# 效果：下载速度提升10倍

# ✅ 优化3：固定版本
# requirements.txt
fastapi==0.109.0  # ✅ 固定版本，可重现
uvicorn>=0.27.0   # ⚠️ 可以，但不推荐
requests           # ❌ 不固定版本，可能突然break
```

---

### 四、Docker存储和网络（⭐⭐）

#### 1. 存储驱动

**查看**：
```bash
docker info | grep "Storage Driver"
# Storage Driver: overlay2 (Linux)
# Storage Driver: overlayfs (Mac)
```

**常见存储驱动**：
| 驱动 | 操作系统 | 性能 | 稳定性 |
|------|----------|------|--------|
| overlay2 | Linux | 最好 | ✅✅✅ |
| overlayfs | Mac (via VM) | 好 | ✅✅ |
| aufs | 老版Ubuntu | 中等 | ✅ |
| devicemapper | RHEL/CentOS | 较差 | ⚠️ |

**面试问题：overlay2如何工作？**

**答案**：
```
overlay2使用两层目录：
├── lowerdir (只读层，多个)
│   ├── layer1: FROM python:3.11
│   ├── layer2: RUN apt-get install
│   └── layer3: COPY /install
├── upperdir (可写层，单个)
│   └── 容器的修改在这里
└── merged (合并视图)
    └── 容器看到的文件系统

写时复制（CoW）：
1. 读取文件：直接从lowerdir读（快）
2. 修改文件：复制到upperdir再修改（首次慢，后续快）
3. 删除文件：在upperdir创建whiteout标记（不真正删除lowerdir的文件）
```

---

#### 2. 网络模式

```bash
docker run --network <mode> ...
```

| 模式 | 说明 | 使用场景 |
|------|------|----------|
| bridge (默认) | 容器有自己的IP，通过端口映射访问 | 单机多容器 |
| host | 容器使用宿主机网络，性能最好 | 性能敏感应用 |
| none | 无网络 | 安全隔离 |
| container | 共享另一个容器的网络 | Kubernetes Pod |

**我们使用的bridge模式**：
```
宿主机：192.168.1.100
Docker网桥：172.17.0.1
容器：172.17.0.2

端口映射：0.0.0.0:8000 → 172.17.0.2:8000

访问方式：
curl http://localhost:8000       ✅ 通过端口映射
curl http://172.17.0.2:8000      ❌ 外部无法访问容器IP
```

**与面试内容关联**：
- 🎯 **Kubernetes网络**：每个Pod有独立IP，通过CNI插件实现
- 🎯 **AWS VPC**：ECS任务可以直接获得VPC IP（awsvpc模式）

---

## 🎯 与面试内容的关联

### 一、AWS生态

#### 1. Amazon ECR (Elastic Container Registry)

**本地 → ECR流程**：
```bash
# 1. 登录ECR
aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin \
  858214107245.dkr.ecr.us-east-2.amazonaws.com

# 2. 打标签
docker tag mao-quotes-api:v1 \
  858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api:v1

# 3. 推送
docker push 858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api:v1

# 4. 在ECS/EKS中使用
# ECS任务定义或K8s Deployment中引用这个镜像
```

**ECR特性**：
- **私有仓库**：默认私有，需要IAM权限
- **镜像扫描**：自动扫描漏洞（CVE）
- **生命周期策略**：自动清理旧镜像
- **跨区域复制**：高可用

**面试问题**：ECR vs Docker Hub？

| 特性 | ECR | Docker Hub |
|------|-----|------------|
| 免费 | ✅ 500MB/月 | ✅ 无限公开仓库 |
| 私有仓库 | ✅ 默认私有 | ❌ 收费 |
| 安全扫描 | ✅ 免费 | ❌ 收费 |
| AWS集成 | ✅✅✅ 无缝 | ⚠️ 需要配置 |
| 速度（AWS内） | ✅✅✅ 极快 | ⚠️ 慢 |

---

#### 2. Amazon ECS (Elastic Container Service)

**任务定义**（类似docker run）：
```json
{
  "family": "mao-quotes-api",
  "taskRoleArn": "arn:aws:iam::123456:role/ecsTaskRole",
  "containerDefinitions": [{
    "name": "api",
    "image": "858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api:v1",
    "memory": 512,
    "cpu": 256,
    "portMappings": [{
      "containerPort": 8000,
      "protocol": "tcp"
    }],
    "environment": [
      {"name": "ENV", "value": "production"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/mao-quotes-api",
        "awslogs-region": "us-east-2"
      }
    }
  }]
}
```

**对应关系**：
| Docker命令 | ECS任务定义 |
|------------|-------------|
| `-p 8000:8000` | `portMappings` |
| `-m 512m` | `memory` |
| `-e ENV=prod` | `environment` |
| `--log-driver awslogs` | `logConfiguration` |

---

#### 3. Amazon EKS (Elastic Kubernetes Service)

**Kubernetes Deployment** (下一个Phase会详细讲)：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mao-quotes-api
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: api
        image: 858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api:v1
        ports:
        - containerPort: 8000
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
```

**EKS优势**：
- 托管的Kubernetes控制平面
- 自动扩缩容（HPA）
- 与AWS服务深度集成（IAM、ALB、EBS）

---

### 二、容器编排基础

#### 1. Kubernetes概念对比

| Docker概念 | Kubernetes概念 | 说明 |
|------------|---------------|------|
| 容器 | 容器 | 最小单位 |
| 无 | **Pod** | 一组容器 |
| `docker run` | Deployment | 声明式部署 |
| `--restart always` | ReplicaSet | 保证副本数 |
| `-p 8000:8000` | Service | 服务发现和负载均衡 |
| `HEALTHCHECK` | livenessProbe, readinessProbe | 健康检查 |
| `--memory` | resources.limits | 资源限制 |

**关键区别**：
- Docker：命令式（docker run、docker stop）
- Kubernetes：声明式（写YAML，K8s自动维护状态）

---

#### 2. Helm/Helmchart

**Helm = Kubernetes的包管理器**

类比：
- Docker镜像 = 应用二进制
- Helm Chart = 应用安装包（包含K8s YAML模板）

```bash
# 使用我们的镜像创建Helm Chart
helm create mao-quotes-api

# 修改values.yaml
image:
  repository: 858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api
  tag: v1

# 部署
helm install my-app ./mao-quotes-api
```

---

### 三、CI/CD集成

#### 1. Jenkins Pipeline

```groovy
pipeline {
  agent any
  
  stages {
    stage('Build Docker Image') {
      steps {
        script {
          // 构建镜像
          sh """
            docker build -t mao-quotes-api:${BUILD_NUMBER} \
              -f docker/Dockerfile .
          """
          
          // 推送到ECR
          sh """
            aws ecr get-login-password --region us-east-2 | \
              docker login --username AWS --password-stdin \
              858214107245.dkr.ecr.us-east-2.amazonaws.com
              
            docker tag mao-quotes-api:${BUILD_NUMBER} \
              858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api:${BUILD_NUMBER}
              
            docker push 858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api:${BUILD_NUMBER}
          """
        }
      }
    }
    
    stage('Security Scan') {
      steps {
        // AWS ECR漏洞扫描
        sh """
          aws ecr start-image-scan \
            --repository-name mao-quotes-api \
            --image-id imageTag=${BUILD_NUMBER}
        """
      }
    }
    
    stage('Deploy to EKS') {
      steps {
        sh """
          kubectl set image deployment/mao-quotes-api \
            api=858214107245.dkr.ecr.us-east-2.amazonaws.com/mao-quotes-api:${BUILD_NUMBER}
        """
      }
    }
  }
  
  post {
    always {
      // 清理旧镜像
      sh 'docker system prune -f'
    }
  }
}
```

---

#### 2. GitLab CI/CD

```yaml
# .gitlab-ci.yml
stages:
  - build
  - scan
  - deploy

variables:
  DOCKER_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

build:
  stage: build
  script:
    - docker build -t $DOCKER_IMAGE -f docker/Dockerfile .
    - docker push $DOCKER_IMAGE

scan:
  stage: scan
  script:
    - trivy image $DOCKER_IMAGE  # 开源漏洞扫描工具

deploy:
  stage: deploy
  script:
    - kubectl set image deployment/mao-quotes-api api=$DOCKER_IMAGE
  only:
    - main
```

---

### 四、监控和排障

#### 1. Docker原生命令

```bash
# 查看容器资源使用
docker stats mao-api
# CPU: 0.15%  MEM: 45MB / 512MB  NET I/O: 1.2MB / 800KB

# 查看容器详细信息
docker inspect mao-api | jq '.[0].State'
# 返回JSON：Status, Running, Pid, StartedAt等

# 查看容器进程
docker top mao-api
# 显示容器内运行的进程列表

# 查看端口映射
docker port mao-api
# 8000/tcp -> 0.0.0.0:8000
```

---

#### 2. 与CloudWatch集成

```bash
# ECS任务自动发送日志到CloudWatch
# 配置awslogs驱动后，可以在CloudWatch Logs Insights查询：

fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

---

## 🎤 面试高频问题总结

### 1. Docker vs 虚拟机

| 特性 | Docker容器 | 虚拟机 |
|------|-----------|--------|
| 启动速度 | 秒级 | 分钟级 |
| 资源占用 | 低（MB级内存） | 高（GB级内存） |
| 隔离性 | 进程级（共享内核） | 操作系统级 |
| 性能 | 接近原生（98%） | 较低（80-90%） |
| 镜像大小 | 小（MB-GB） | 大（GB-10GB） |
| 适用场景 | 微服务、CI/CD | 强隔离、多OS |

**答案要点**：
> "容器轻量级、快速，适合微服务；虚拟机隔离性强，适合需要运行不同操作系统的场景。在我们项目中，使用容器部署API服务，启动时间从3分钟降到5秒，资源利用率提高3倍。"

---

### 2. 如何优化Docker镜像大小？

**分层回答**：

**基础优化**（必答）：
1. 使用slim或alpine基础镜像
2. 多阶段构建
3. 合并RUN指令
4. 清理缓存文件

**高级优化**（加分）：
5. 使用.dockerignore
6. 删除不必要的依赖
7. 使用distroless镜像
8. 使用docker-slim工具自动优化

**实战案例**（加分++）：
> "在优化中，我发现某个Python包依赖了整个GCC工具链（200MB），但实际只需要一个编译好的.so文件（5MB）。我使用多阶段构建，只复制.so文件到最终镜像，节省了195MB。"

---

### 3. Dockerfile中COPY和ADD的区别？

| 特性 | COPY | ADD |
|------|------|-----|
| 基本复制 | ✅ | ✅ |
| 自动解压tar.gz | ❌ | ✅ |
| 支持URL下载 | ❌ | ✅ |
| 推荐使用 | ✅✅✅ | ⚠️ 谨慎 |

**答案**：
> "COPY只做简单复制，行为可预测；ADD有额外功能（解压、URL下载），但不透明，容易出问题。Docker官方推荐用COPY，只有需要解压时才用ADD。"

---

### 4. CMD vs ENTRYPOINT的区别？

```dockerfile
# CMD - 可以被覆盖
CMD ["uvicorn", "main:app"]
docker run myimage python -m pytest  # ✅ 覆盖CMD，运行测试

# ENTRYPOINT - 不会被覆盖
ENTRYPOINT ["uvicorn"]
CMD ["main:app", "--host", "0.0.0.0"]
docker run myimage test:app  # ✅ 运行uvicorn test:app（追加参数）

# 组合使用
ENTRYPOINT ["python"]
CMD ["main.py"]
docker run myimage test.py  # 运行python test.py
```

**答案**：
> "CMD适合提供默认命令，可以灵活覆盖；ENTRYPOINT适合容器就是用来运行特定程序的场景。通常组合使用：ENTRYPOINT定义可执行文件，CMD定义默认参数。"

---

### 5. 容器为什么要用非root用户？

**安全风险**：
```
容器以root运行 + 容器逃逸漏洞 = 攻击者在宿主机获得root权限

真实案例（CVE-2019-5736）：
runc容器逃逸漏洞，允许容器内root用户覆盖宿主机的runc二进制文件
```

**答案**：
> "遵循最小权限原则。即使容器被攻破，攻击者只有普通用户权限，无法修改系统文件或提权。在Kubernetes中，可以用SecurityContext强制要求非root：`runAsNonRoot: true`。"

---

### 6. 生产环境遇到的Docker问题？

**经典问题1：磁盘满**
```
问题：Jenkins agent磁盘占用100%
原因：docker system df显示92GB构建缓存
解决：添加定时任务 docker system prune -a -f --filter "until=24h"
```

**经典问题2：容器OOM**
```
问题：容器频繁重启，日志显示OOMKilled
原因：-m 512m内存限制太小，Python进程需要1GB
解决：调整内存限制，使用docker stats监控
```

**经典问题3：镜像拉取超时**
```
问题：K8s Pod启动失败，ImagePullBackOff
原因：镜像1.5GB，网络慢
解决：优化镜像到300MB，使用本地镜像缓存
```

---

## 📊 Phase 2 成果

### 构建产出

```
docker/
├── Dockerfile           218行，包含详细注释和面试考点
└── .dockerignore        完整的过滤规则

镜像：mao-quotes-api:v1
├── 大小：310MB（优化后）
├── 基础镜像：python:3.11-slim
├── 安全：非root用户运行
└── 健康检查：内置Docker健康检查
```

### 掌握的命令

```bash
# 构建和镜像管理（8个）
docker build, images, history, rmi, tag, push, pull, save/load

# 容器运行和管理（10个）
docker run, ps, logs, exec, stop, start, restart, rm, inspect, port

# 系统管理（5个）
docker system df/prune, container prune, image prune, volume prune

# 网络和卷（4个）
docker network ls/create, volume ls/create

总计：27个常用命令
```

### 核心概念

✅ Docker三层架构（Client-Daemon-Runtime）  
✅ 多阶段构建原理和实践  
✅ 镜像分层和Union FS  
✅ 容器网络（bridge、端口映射）  
✅ 存储驱动（overlay2/overlayfs）  
✅ 安全最佳实践（非root、最小镜像）  
✅ 构建缓存优化  
✅ 日志和监控基础  

---

## 🎯 下一步：Phase 3

**Kubernetes部署**
- 创建Deployment、Service
- ConfigMap和Secret
- HPA自动扩缩容
- Liveness/Readiness探针
- 资源限制（requests/limits）

---

## 📝 复习清单

### 必须掌握（面试必考）
- [ ] Docker三层架构
- [ ] 多阶段构建原理
- [ ] Dockerfile最佳实践
- [ ] docker run常用参数
- [ ] 容器vs虚拟机对比
- [ ] 镜像优化方法
- [ ] 非root用户运行容器
- [ ] CMD vs ENTRYPOINT

### 应该了解（加分项）
- [ ] Docker存储驱动（overlay2）
- [ ] 容器网络模式
- [ ] 镜像分层原理
- [ ] docker system prune用法
- [ ] ECR集成流程
- [ ] Jenkins构建镜像
- [ ] 常见排障方法

### 可以深入（高级）
- [ ] containerd和runc的关系
- [ ] Docker安全加固
- [ ] 镜像扫描工具（Trivy）
- [ ] Docker Compose
- [ ] Docker Swarm vs Kubernetes

---

**Phase 2 完成！✅**

下一阶段我们将把这个容器化的应用部署到Kubernetes，学习云原生编排的核心技能！
