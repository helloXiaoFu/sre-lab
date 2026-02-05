# ============================================
# 多阶段构建 Dockerfile
# SRE最佳实践：减小镜像体积，提高安全性
# ============================================

# ============================================
# Stage 1: 构建阶段 (Builder)
# 目的：安装依赖、编译代码
# ============================================
FROM python:3.11-slim as builder

# 设置工作目录
# 为什么？所有后续命令都在这个目录执行
WORKDIR /build

# 安装构建依赖
# 面试问题：为什么要 --no-install-recommends？
# 答：只安装必需的包，不安装推荐包，减小镜像体积
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*
# 面试问题：为什么要 rm -rf /var/lib/apt/lists/*？
# 答：清理apt缓存，减小镜像层大小

# 复制依赖文件
# 为什么先复制requirements.txt而不是整个app目录？
# 答：利用Docker构建缓存。如果requirements.txt没变，这层就会使用缓存
COPY app/requirements.txt .

# 安装Python依赖到指定目录
# 面试问题：为什么用 --prefix=/install？
# 答：多阶段构建中，需要把安装的依赖复制到最终镜像
# --no-cache-dir：不保存pip缓存，减小镜像体积
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================
# Stage 2: 运行阶段 (Runtime)
# 目的：最小化最终镜像，只包含运行时需要的文件
# ============================================
FROM python:3.11-slim

# ============================================
# 元数据标签（最佳实践）
# 用途：标识镜像信息，方便管理
# ============================================
LABEL maintainer="sre-team@example.com" \
      app="mao-quotes-api" \
      version="1.0.0" \
      description="毛主席语录AI鼓励系统"

# ============================================
# 创建非root用户（安全最佳实践）
# 面试高频：为什么容器不应该用root运行？
# ============================================
# 答案：
# 1. 最小权限原则 - 应用不需要root权限
# 2. 容器逃逸风险 - root用户逃逸后可以控制宿主机
# 3. 合规要求 - 很多安全标准要求非root

# groupadd -r：创建系统组（-r = system group，UID < 1000）
# useradd -r：创建系统用户，不创建home目录
RUN groupadd -r appuser && \
    useradd -r -g appuser -u 1000 appuser

# 设置工作目录
WORKDIR /app

# ============================================
# 从构建阶段复制依赖
# 面试问题：什么是多阶段构建的好处？
# ============================================
# 答案：
# 1. 减小镜像体积 - 最终镜像不包含gcc等构建工具
# 2. 提高安全性 - 减少攻击面
# 3. 加快构建速度 - 可以并行构建
COPY --from=builder /install /usr/local

# ============================================
# 复制应用代码
# 面试问题：为什么放在最后复制？
# ============================================
# 答案：利用Docker构建缓存
# - 依赖不常变化，放前面可以重用缓存
# - 代码经常变化，放后面只重建这层
COPY --chown=appuser:appuser app/ .

# ============================================
# 更改文件所有者
# 为什么需要？因为COPY默认是root拥有
# ============================================
# 注意：上面COPY时已经用了--chown，这行实际可以省略
# 但保留是为了演示这个操作
# RUN chown -R appuser:appuser /app

# ============================================
# 切换到非root用户
# 从这一行开始，所有命令都以appuser身份运行
# ============================================
USER appuser

# ============================================
# 暴露端口
# 面试问题：EXPOSE的作用是什么？
# ============================================
# 答案：
# 1. 文档作用 - 告诉使用者这个容器监听哪个端口
# 2. 不会真正开放端口 - 需要在docker run时用-p指定
# 3. docker-compose可以自动映射EXPOSE的端口
EXPOSE 8000

# ============================================
# 健康检查（Docker原生健康检查）
# 面试问题：这和Kubernetes的健康检查有什么区别？
# ============================================
# 答案：
# - Docker健康检查：Docker层面，单容器
# - K8s健康检查：编排层面，整个Pod
# - K8s会覆盖Docker的健康检查
# - 但Docker健康检查对本地开发很有用
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=3)" || exit 1
# 参数说明：
# --interval=30s：每30秒检查一次
# --timeout=5s：检查超时时间5秒
# --start-period=10s：容器启动后10秒才开始检查（给应用启动时间）
# --retries=3：连续失败3次才认为不健康

# ============================================
# 启动命令
# 面试问题：CMD vs ENTRYPOINT的区别？
# ============================================
# 答案：
# CMD：
#   - 可以被docker run的参数覆盖
#   - 适合提供默认命令
# ENTRYPOINT：
#   - 不会被覆盖，docker run的参数会追加
#   - 适合容器就是用来运行特定命令
# 
# 这里用CMD，方便开发时覆盖（如运行测试）

# 为什么用JSON数组格式（exec形式）而不是字符串？
# exec形式：["uvicorn", "main:app"]
# shell形式："uvicorn main:app"
# 
# exec形式的优势：
# 1. 正确处理信号（SIGTERM等）- 优雅关闭
# 2. 不会创建额外的shell进程
# 3. 更快的启动速度
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]

# 面试问题：为什么workers设置为1？
# 答案：
# - 单容器单进程原则（12-factor app）
# - 水平扩展：需要更多并发就启动更多容器（K8s管理）
# - 如果在容器内多进程，难以监控和管理
# 生产环境：通过K8s的HPA自动扩缩容实现并发

# ============================================
# Dockerfile 优化技巧总结
# ============================================
# 1. 多阶段构建 - 减小最终镜像
# 2. 合并RUN命令 - 减少镜像层数
# 3. 清理缓存 - rm -rf /var/lib/apt/lists/*
# 4. 利用构建缓存 - 不常变的指令放前面
# 5. 非root用户 - 安全最佳实践
# 6. .dockerignore - 避免复制不需要的文件
# 7. 使用slim/alpine镜像 - 减小基础镜像体积

# ============================================
# 镜像构建命令
# ============================================
# 在项目根目录执行：
# docker build -t mao-quotes-api:v1 -f docker/Dockerfile .
#
# 参数说明：
# -t mao-quotes-api:v1  : 给镜像打标签（名称:版本）
# -f docker/Dockerfile  : 指定Dockerfile路径
# .                     : 构建上下文（项目根目录）

# ============================================
# 镜像运行命令
# ============================================
# docker run -d \
#   --name mao-api \
#   -p 8000:8000 \
#   -e ENV=production \
#   --restart unless-stopped \
#   mao-quotes-api:v1
#
# 参数说明：
# -d                    : 后台运行
# --name mao-api        : 容器名称
# -p 8000:8000          : 端口映射（宿主机:容器）
# -e ENV=production     : 环境变量
# --restart unless-stopped : 自动重启策略

# ============================================
# 常用排障命令
# ============================================
# 查看运行的容器：
#   docker ps
#
# 查看容器日志：
#   docker logs -f mao-api
#
# 进入容器排障：
#   docker exec -it mao-api /bin/bash
#
# 查看容器资源使用：
#   docker stats mao-api
#
# 查看镜像分层：
#   docker history mao-quotes-api:v1
#
# 查看镜像详细信息：
#   docker inspect mao-quotes-api:v1
