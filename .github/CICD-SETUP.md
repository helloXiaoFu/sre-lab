# CI/CD配置指南

这个文档说明如何配置GitHub Actions CI/CD Pipeline。

---

## 📋 前置要求

1. **GitHub仓库**：代码托管在GitHub
2. **AWS账号**：用于ECR和EKS
3. **EKS集群**：已创建并运行
4. **ECR仓库**：Docker镜像存储

---

## 🔐 配置GitHub Secrets

Secrets用于存储敏感信息（如AWS凭证），不会暴露在代码中。

### 步骤1：创建IAM用户（用于GitHub Actions）

在AWS Console中：

```bash
# 1. 创建IAM用户
aws iam create-user --user-name github-actions

# 2. 创建访问密钥
aws iam create-access-key --user-name github-actions

# 保存输出的AccessKeyId和SecretAccessKey
```

### 步骤2：附加权限策略

GitHub Actions需要以下权限：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

保存为`github-actions-policy.json`，然后附加：

```bash
aws iam put-user-policy \
  --user-name github-actions \
  --policy-name GitHubActionsPolicy \
  --policy-document file://github-actions-policy.json
```

### 步骤3：在GitHub配置Secrets

1. 打开GitHub仓库
2. 进入 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 添加以下Secrets：

| Secret名称 | 值 | 说明 |
|-----------|---|------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | IAM用户的Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | `wJalr...` | IAM用户的Secret Access Key |

> **注意**：这些Secrets一旦保存就无法查看，只能更新。

---

## 🏗️  配置GitHub Environments（可选）

Environments用于管理不同环境（dev/staging/prod）的配置和审批流程。

### 创建Environment

1. 进入 **Settings** → **Environments**
2. 点击 **New environment**
3. 创建3个环境：
   - `dev`：开发环境（无需审批）
   - `staging`：测试环境（可选审批）
   - `prod`：生产环境（**必须审批**）

### 配置Production审批规则

对于`prod`环境：

1. 点击 **prod** environment
2. 勾选 **Required reviewers**
3. 添加审批人（团队Lead或Senior工程师）
4. 设置 **Wait timer**（可选，例如5分钟冷却期）

这样，部署到生产环境时会：
1. 暂停Workflow
2. 通知审批人
3. 审批后才继续部署

---

## 🚀 工作流说明

### 1. CI Pipeline（ci.yml）

**触发条件**：
- Push到`main`或`dev`分支
- 创建PR到`main`分支
- 手动触发

**执行流程**：
```
1. Lint（代码检查）
   ↓
2. Test（单元测试）
   ↓
3. Build（构建Docker镜像）
   ↓
4. Push（推送到ECR）
```

**耗时**：约5-8分钟

### 2. CD Pipeline（cd.yml）

**触发条件**：
- CI Pipeline成功完成
- 手动触发（可选择环境和镜像tag）

**执行流程**：
```
1. 配置AWS和kubectl
   ↓
2. 更新Deployment镜像
   ↓
3. 等待滚动更新完成
   ↓
4. 验证部署状态
   ↓
5. 运行烟雾测试
   ↓
6. 发送通知
```

**耗时**：约3-5分钟

### 3. Rollback（rollback.yml）

**触发条件**：
- 仅手动触发（紧急情况）

**执行流程**：
```
1. 显示当前状态和历史版本
   ↓
2. 确认回滚（Environment审批）
   ↓
3. 执行回滚
   ↓
4. 验证健康状态
   ↓
5. 记录和通知
```

**耗时**：约2-3分钟

---

## 📊 查看Workflow执行

### 在GitHub UI查看

1. 进入仓库的 **Actions** 标签
2. 选择Workflow（CI Pipeline/CD Pipeline）
3. 查看运行历史和详细日志

### 常见状态

- 🟢 **Success**：所有步骤成功
- 🔴 **Failure**：有步骤失败
- 🟡 **In progress**：正在运行
- ⚪ **Queued**：等待运行
- 🟠 **Waiting**：等待审批

---

## 🔍 故障排查

### 问题1：CI失败 - "Lint errors"

**原因**：代码不符合风格规范

**解决**：
```bash
# 本地运行linter
black app/
isort app/
flake8 app/

# 修复后重新提交
git add .
git commit -m "Fix linting errors"
git push
```

### 问题2：CD失败 - "Unable to connect to EKS"

**原因**：AWS凭证或权限问题

**排查**：
1. 检查Secrets是否正确配置
2. 确认IAM用户有EKS访问权限
3. 确认EKS集群名称正确

### 问题3：部署超时

**原因**：镜像拉取慢或Pod启动失败

**排查**：
```bash
# 查看Pod状态
kubectl get pods -l app=mao-api

# 查看Pod日志
kubectl logs -l app=mao-api

# 查看Events
kubectl get events --sort-by='.lastTimestamp'
```

---

## 🎯 最佳实践

### 1. 分支策略

```
main（生产）← PR merge
 ↑
dev（开发）← feature branches
 ↑
feature/xxx（功能开发）
```

**工作流程**：
1. 从`dev`创建feature分支
2. 开发完成后PR到`dev`
3. 在`dev`环境测试
4. 测试通过后PR到`main`
5. 自动部署到生产（需审批）

### 2. 提交规范

使用[Conventional Commits](https://www.conventionalcommits.org/)：

```
feat: 添加新功能
fix: 修复Bug
docs: 文档更新
style: 代码格式（不影响逻辑）
refactor: 重构
test: 测试相关
chore: 构建/工具相关
```

### 3. 版本标签

使用Semantic Versioning：

```bash
git tag v1.0.0
git push origin v1.0.0
```

可以配置基于tag的部署：

```yaml
on:
  push:
    tags:
      - 'v*.*.*'
```

### 4. 监控和告警

部署后监控：
- CloudWatch Metrics（CPU、内存、请求数）
- CloudWatch Alarms（异常告警）
- Application Logs（错误日志）

### 5. 回滚策略

- **快速回滚**：使用Rollback workflow（2分钟）
- **验证回滚**：确认回滚后服务正常
- **根因分析**：分析问题原因，避免重复

### 6. 安全建议

✅ **应该做**：
- Secrets存储敏感信息
- 生产环境需要审批
- 最小权限原则（IAM）
- 定期轮换AWS密钥
- 记录所有部署操作

❌ **不应该做**：
- 硬编码密码/密钥
- 跳过代码审查
- 直接修改生产环境
- 没有测试就部署

---

## 📚 参考资料

- [GitHub Actions文档](https://docs.github.com/en/actions)
- [AWS EKS文档](https://docs.aws.amazon.com/eks/)
- [Kubernetes文档](https://kubernetes.io/docs/)
- [Docker最佳实践](https://docs.docker.com/develop/dev-best-practices/)

---

## 🆘 获取帮助

如果遇到问题：
1. 查看GitHub Actions日志
2. 查看kubectl日志：`kubectl logs -l app=mao-api`
3. 查看EKS Events：`kubectl get events`
4. 查看本文档的故障排查部分

---

**配置完成后，你的CI/CD Pipeline就可以自动工作了！** 🎉

每次代码提交都会自动：
- ✅ 代码检查
- ✅ 运行测试
- ✅ 构建镜像
- ✅ 部署到EKS
- ✅ 验证健康

**部署时间从30分钟降低到5分钟！** 🚀
