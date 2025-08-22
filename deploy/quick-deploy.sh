#!/bin/bash
# quick-deploy.sh - AlgerMusicPlayer 快速部署脚本

echo "🚀 AlgerMusicPlayer 快速部署到 Debian 服务器"
echo "=============================================="

# 检查是否在项目根目录或 deploy 目录
if [ -f "../package.json" ]; then
    # 在 deploy 目录下运行
    PROJECT_ROOT="../"
elif [ -f "package.json" ]; then
    # 在项目根目录下运行
    PROJECT_ROOT="./"
else
    echo "❌ 请在项目根目录或 deploy 目录下运行此脚本"
    exit 1
fi

# 使用 deploy-debian.sh 进行部署
DEPLOY_SCRIPT="${PROJECT_ROOT}deploy/deploy-debian.sh"
if [ -f "$DEPLOY_SCRIPT" ]; then
    echo "✅ 找到部署脚本，开始执行..."
    chmod +x "$DEPLOY_SCRIPT"
    cd "$PROJECT_ROOT"
    exec ./deploy/deploy-debian.sh "$@"
else
    echo "❌ 部署脚本不存在: $DEPLOY_SCRIPT"
    exit 1
fi
