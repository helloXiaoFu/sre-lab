# -*- coding: utf-8 -*-
"""
毛主席语录AI鼓励系统 - FastAPI应用
这是SRE学习项目的核心API服务

涉及的SRE知识点：
1. 健康检查（Liveness & Readiness Probes）
2. 结构化日志（Request Tracing）
3. 监控指标（Metrics）
4. 优雅关闭（Graceful Shutdown）
5. 错误处理（Error Handling）
"""

import logging
import time
from datetime import datetime
from typing import Dict, Any

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# 导入我们自己的语录模块
from quotes import get_quote_by_keyword, get_random_quote, get_total_quotes


# ============================================
# 日志配置 - SRE第一原则：可观测性
# ============================================
# 为什么日志如此重要？
# - 故障排查的唯一线索
# - 审计和合规要求
# - 性能分析和优化

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    # 生产环境应该输出JSON格式日志（便于日志聚合系统解析）
    # format='{"time":"%(asctime)s","name":"%(name)s","level":"%(levelname)s","msg":"%(message)s"}'
)
logger = logging.getLogger(__name__)


# ============================================
# FastAPI应用初始化
# ============================================
app = FastAPI(
    title="毛主席语录AI鼓励系统",
    description="用毛主席语录鼓励用户的AI服务",
    version="1.0.0",
    # 自动生成的API文档地址
    docs_url="/docs",      # Swagger UI（交互式文档）
    redoc_url="/redoc",    # ReDoc（更美观的文档）
)

# Auto-generated API documentation for better developer experience


# Request/Response Models
class ChatRequest(BaseModel):
    """
    聊天请求模型
    
    Pydantic会自动验证：
    - 字段类型是否正确
    - 必填字段是否存在
    - 字段值是否符合约束
    
    如果验证失败，自动返回422错误
    """
    message: str
    user_id: str = "anonymous"  # 可选字段，默认值
    
    # 可以添加更多验证
    # from pydantic import Field, validator
    # message: str = Field(..., min_length=1, max_length=1000)


class ChatResponse(BaseModel):
    """聊天响应模型"""
    quote: str              # 返回的语录
    timestamp: str          # 时间戳
    request_id: str         # 请求追踪ID


class HealthResponse(BaseModel):
    """健康检查响应模型"""
    status: str            # healthy / unhealthy
    timestamp: str
    version: str
    quotes_count: int      # 语录数量（用于验证数据加载）


# ============================================
# 全局变量 - 用于简单的metrics
# ============================================
# 注意：这是简化版，生产环境应该用Prometheus
request_count = 0
start_time = time.time()


# ============================================
# 中间件 - 请求拦截与日志
# ============================================
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """
    记录所有HTTP请求
    
    SRE知识点：中间件（Middleware）
    - 在每个请求到达endpoint之前执行
    - 在每个响应返回之前执行
    - 用途：日志、认证、限流、CORS等
    
    面试问题：为什么要记录request_id？
    答：分布式系统中追踪一个请求的完整生命周期
       请求可能经过：ALB -> Pod1 -> DynamoDB -> SQS
       通过request_id可以关联所有日志
    """
    global request_count
    request_count += 1
    
    # 生成唯一的请求ID
    request_id = f"req-{int(time.time() * 1000)}-{request_count}"
    start = time.time()
    
    # 记录请求开始
    logger.info(f"[{request_id}] {request.method} {request.url.path} - Start")
    
    try:
        # 调用实际的endpoint处理函数
        response = await call_next(request)
        
        # 计算请求处理时间
        duration = time.time() - start
        
        # 记录请求完成
        logger.info(
            f"[{request_id}] {request.method} {request.url.path} - "
            f"Status: {response.status_code} - Duration: {duration:.3f}s"
        )
        
        # 在响应头中添加追踪信息
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time"] = f"{duration:.3f}s"
        
        return response
        
    except Exception as e:
        duration = time.time() - start
        logger.error(
            f"[{request_id}] {request.method} {request.url.path} - "
            f"Error: {str(e)} - Duration: {duration:.3f}s"
        )
        raise


# ============================================
# API端点（Endpoints）
# ============================================

@app.get("/", response_model=Dict[str, Any])
async def root():
    """
    根路径 - 服务信息
    访问: http://localhost:8000/
    """
    return {
        "service": "毛主席语录AI鼓励系统",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "health": "/health",
        "ready": "/ready",
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """
    健康检查端点（Liveness Probe）
    
    SRE知识点：Liveness Probe
    - Kubernetes用这个检查容器是否"活着"
    - 如果失败，K8s会重启Pod
    - 应该检查：服务基本功能是否正常
    - 不应该检查：外部依赖（数据库等）- 那是readiness的工作
    
    返回：200 OK表示健康
    """
    return HealthResponse(
        status="healthy",
        timestamp=datetime.now().isoformat(),
        version="1.0.0",
        quotes_count=get_total_quotes()
    )


@app.get("/ready")
async def readiness_check():
    """
    就绪检查端点（Readiness Probe）
    
    SRE知识点：Readiness Probe
    - Kubernetes用这个检查容器是否"准备好"接收流量
    - 如果失败，K8s会把Pod从Service的endpoints中移除
    - 应该检查：所有依赖是否就绪（数据库连接、缓存、配置等）
    
    Liveness vs Readiness的区别：
    - Liveness：进程是否活着？（失败→重启）
    - Readiness：服务是否准备好？（失败→暂停流量）
    
    例子：
    - 应用正在加载大量数据 → Liveness=OK, Readiness=FAIL
    - 数据库连接断开 → Liveness=OK, Readiness=FAIL
    - 进程卡死 → Liveness=FAIL → 重启
    """
    # 检查语录是否加载
    if get_total_quotes() == 0:
        raise HTTPException(
            status_code=503,  # 503 Service Unavailable
            detail="Service not ready: No quotes loaded"
        )
    
    # 生产环境还应该检查：
    # - 数据库连接：db.ping()
    # - Redis连接：redis.ping()
    # - 配置加载：config.is_loaded()
    
    return {
        "status": "ready",
        "timestamp": datetime.now().isoformat()
    }


@app.get("/metrics")
async def metrics():
    """
    指标端点（简化版）
    
    SRE知识点：监控指标（Metrics）
    - Google SRE四大黄金信号：延迟、流量、错误、饱和度
    - RED方法：Rate（速率）、Errors（错误）、Duration（延迟）
    
    生产环境应该：
    - 使用Prometheus格式（prometheus_client库）
    - 暴露更多指标（CPU、内存、请求分布等）
    - 配合Grafana做可视化
    """
    uptime = time.time() - start_time
    return {
        "request_count": request_count,      # 总请求数
        "uptime_seconds": uptime,           # 运行时间
        "quotes_count": get_total_quotes(), # 语录数量
        # 生产环境还应该有：
        # "error_rate": error_count / request_count,
        # "avg_latency_ms": total_latency / request_count,
        # "cpu_usage_percent": psutil.cpu_percent(),
        # "memory_usage_mb": psutil.virtual_memory().used / 1024 / 1024,
    }


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    聊天端点 - 核心业务逻辑
    
    接收用户消息，返回毛主席语录鼓励
    
    访问: POST http://localhost:8000/chat
    请求体: {"message": "今天好累啊", "user_id": "user123"}
    """
    try:
        # 1. 输入验证（Pydantic已自动完成基础验证）
        if not request.message or len(request.message.strip()) == 0:
            raise HTTPException(
                status_code=400,  # 400 Bad Request
                detail="消息不能为空"
            )
        
        if len(request.message) > 1000:
            raise HTTPException(
                status_code=400,
                detail="消息过长（最多1000字符）"
            )
        
        # 2. 记录请求（便于审计和调试）
        logger.info(
            f"User: {request.user_id} - "
            f"Message: {request.message[:50]}..."  # 只记录前50字符
        )
        
        # 3. 核心业务逻辑 - 获取语录
        quote = get_quote_by_keyword(request.message)
        
        # 4. 构造响应
        response = ChatResponse(
            quote=quote,
            timestamp=datetime.now().isoformat(),
            request_id=f"req-{int(time.time() * 1000)}"
        )
        
        # 5. 记录响应
        logger.info(f"Response quote: {quote}")
        
        return response
        
    except HTTPException:
        # HTTPException会被FastAPI自动处理，直接抛出
        raise
        
    except Exception as e:
        # 捕获所有其他异常
        logger.error(f"Unexpected error in chat endpoint: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,  # 500 Internal Server Error
            detail="内部服务器错误"
        )


@app.get("/quotes/random")
async def random_quote():
    """
    获取随机语录（简单端点，用于测试）
    
    访问: GET http://localhost:8000/quotes/random
    """
    return {
        "quote": get_random_quote(),
        "timestamp": datetime.now().isoformat()
    }


# ============================================
# 全局异常处理器
# ============================================
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    全局异常处理
    
    SRE知识点：错误处理最佳实践
    - 统一错误响应格式
    - 不暴露敏感信息（堆栈、内部路径等）
    - 详细错误记录到日志（用于排查）
    - 返回友好错误信息给用户
    """
    logger.error(
        f"Unhandled exception: {str(exc)}",
        exc_info=True  # 记录完整堆栈
    )
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": "服务暂时不可用，请稍后重试",
            "timestamp": datetime.now().isoformat(),
            # 生产环境不要返回详细错误信息！
            # "detail": str(exc)  #  危险
        }
    )


# ============================================
# 应用生命周期事件
# ============================================
@app.on_event("startup")
async def startup_event():
    """
    应用启动时执行
    
    SRE用途：
    - 预加载数据（如缓存预热）
    - 初始化连接池（数据库、Redis）
    - 健康检查依赖服务
    - 注册服务到服务发现
    """
    logger.info("Mao Quotes API Server starting")
    logger.info(f"Loaded {get_total_quotes()} quotes")
    logger.info("Server ready - API docs at http://localhost:8000/docs")


@app.on_event("shutdown")
async def shutdown_event():
    """
    应用关闭时执行
    
    SRE知识点：优雅关闭（Graceful Shutdown）
    - 停止接收新请求
    - 完成正在处理的请求
    - 关闭数据库连接
    - 清理资源
    - 从服务发现注销
    
    为什么重要？
    - 避免请求失败
    - 避免数据丢失
    - 避免资源泄露
    """
    logger.info("=" * 50)
    logger.info("🛑 服务正在关闭...")
    logger.info(f" 总共处理了 {request_count} 个请求")
    logger.info("👋 再见！")
    logger.info("=" * 50)


# ============================================
# 主函数（开发模式）
# ============================================
if __name__ == "__main__":
    """
    直接运行此文件时启动服务
    
    开发环境：python main.py
    生产环境：uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
    
    面试问题：开发环境和生产环境的区别？
    答：
    - 开发：单进程、热重载、详细日志
    - 生产：多进程、无重载、结构化日志、监控集成
    """
    import uvicorn
    
    uvicorn.run(
        "main:app",              # 应用路径
        host="0.0.0.0",         # 监听所有网络接口（容器中必需）
        port=8000,              # 端口
        reload=True,            # 开发模式：代码变更自动重启
        log_level="info"        # 日志级别
    )
