#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GitHub准备清理脚本
# 用途：清理学习痕迹，让项目更专业
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

PROJECT_ROOT="/Users/fudongxiao/Downloads/AllCode/sre-lab"
cd "$PROJECT_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 开始清理项目..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. 清理代码中的装饰性emoji（保留合理的）
echo "1️⃣  清理代码中的装饰性emoji..."

# 清理Python文件中的emoji（保留合理的TODO, NOTE等）
find . -type f -name "*.py" \
  -not -path "./venv/*" \
  -not -path "./.git/*" \
  -exec sed -i.backup \
    -e 's/🚀//g' \
    -e 's/📚//g' \
    -e 's/✅//g' \
    -e 's/📖//g' \
    -e 's/⚠️//g' \
    -e 's/❌//g' \
    -e 's/🎯//g' \
    -e 's/💡//g' \
    -e 's/🔧//g' \
    -e 's/📊//g' \
    -e 's/🎉//g' \
    {} \;

echo "   ✓ Python文件emoji清理完成"

# 清理YAML文件中的过度emoji
find . -type f \( -name "*.yml" -o -name "*.yaml" \) \
  -not -path "./venv/*" \
  -not -path "./.git/*" \
  -exec sed -i.backup \
    -e 's/━━━.*━━━//g' \
    {} \;

echo "   ✓ YAML文件装饰线清理完成"

# 2. 删除过长的装饰性分隔线
echo ""
echo "2️⃣  删除过长的装饰性分隔线..."

find . -type f \( -name "*.py" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) \
  -not -path "./venv/*" \
  -not -path "./.git/*" \
  -not -path "./.terraform/*" \
  -exec sed -i.backup \
    -e '/^# ={40,}/d' \
    -e '/^# ━{40,}/d' \
    {} \;

echo "   ✓ 装饰性分隔线清理完成"

# 3. 替换AWS Account ID为占位符
echo ""
echo "3️⃣  替换AWS Account ID..."

# 在代码文件中替换（但保留docs中的示例）
find . -type f \( -name "*.py" -o -name "*.yml" -o -name "*.yaml" -o -name "*.tf" \) \
  -not -path "./docs/*" \
  -not -path "./venv/*" \
  -not -path "./.git/*" \
  -not -path "./.terraform/*" \
  -exec sed -i.backup \
    -e 's/615299755285/<YOUR_AWS_ACCOUNT_ID>/g' \
    {} \;

echo "   ✓ AWS Account ID已替换为占位符"

# 4. 清理backup文件
echo ""
echo "4️⃣  清理临时backup文件..."
find . -name "*.backup" -delete
echo "   ✓ Backup文件已清理"

# 5. 检查是否还有敏感信息
echo ""
echo "5️⃣  最终检查敏感信息..."

SENSITIVE_FOUND=0

# 检查真实的AWS Access Key格式（但跳过示例）
if grep -r "AKIA[0-9A-Z]\{16\}" . \
  --exclude-dir=.git \
  --exclude-dir=venv \
  --exclude-dir=.terraform \
  --exclude="*.backup" 2>/dev/null | grep -v "AKIAIOSFODNN7EXAMPLE" | grep -v "docs/" | head -1; then
  echo "   ⚠️  警告：发现可能的真实AWS Access Key"
  SENSITIVE_FOUND=1
fi

# 检查明文密码（但跳过示例）
if grep -ri "password.*=.*['\"].\{8,\}['\"]" . \
  --include="*.py" \
  --include="*.yml" \
  --include="*.yaml" 2>/dev/null | grep -v "example" | grep -v "DB_PASSWORD" | head -1; then
  echo "   ⚠️  警告：发现可能的明文密码"
  SENSITIVE_FOUND=1
fi

if [ $SENSITIVE_FOUND -eq 0 ]; then
  echo "   ✓ 未发现敏感信息"
fi

# 6. 总结
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 清理完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 完成的清理项："
echo "   ✓ 删除quiz文件"
echo "   ✓ 重命名docs文档"
echo "   ✓ 清理装饰性emoji"
echo "   ✓ 删除过长分隔线"
echo "   ✓ 替换AWS Account ID"
echo "   ✓ 创建.gitignore"
echo ""
echo "📝 下一步："
echo "   1. 检查修改后的文件是否正常"
echo "   2. 运行: git init"
echo "   3. 运行: git add ."
echo "   4. 运行: git commit -m \"Initial commit: Enterprise SRE practice project\""
echo "   5. 在GitHub创建仓库并推送"
echo ""
echo "🎯 提示："
echo "   - README.md需要手动检查和调整"
echo "   - 确认所有修改符合预期后再git add"
echo ""
