#!/bin/bash
# fix-deploy.sh - 修复部署问题的快速脚本

echo "🔧 修复部署路径问题..."

# 检查当前位置
echo "📍 当前目录: $(pwd)"
echo "📁 目录内容:"
ls -la | head -10

# 检查是否在项目根目录
if [ ! -f "package.json" ]; then
    echo "❌ 当前不在项目根目录"
    echo "💡 请执行: cd /opt/AlgerMusicPlayer"
    exit 1
fi

echo "✅ 确认在项目根目录"

# 检查系统资源
echo ""
echo "📊 系统资源状态:"
echo "内存:"
free -h
echo ""
echo "磁盘:"
df -h .

# 检查 Docker 状态
echo ""
echo "🐳 Docker 状态:"
docker --version
docker-compose --version

# 检查 Node.js
echo ""
echo "📦 Node.js 状态:"
node --version
npm --version

echo ""
echo "🚀 现在可以重新运行部署:"
echo "   ./deploy/deploy-debian.sh"
echo ""
echo "或者使用低内存模式:"
echo "   ./deploy/low-memory-deploy.sh"
