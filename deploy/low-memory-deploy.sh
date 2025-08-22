#!/bin/bash
# low-memory-deploy.sh - 专为低内存服务器设计的部署脚本

echo "🔧 低内存服务器部署修复脚本"
echo "================================="

# 检查当前目录
if [ ! -f "package.json" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

# 显示系统信息
echo "📊 系统资源状态:"
echo "内存:"
free -h
echo ""
echo "磁盘空间:"
df -h .
echo ""

# 获取可用内存 (MB)
AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')

echo "总内存: ${TOTAL_MEM}MB"
echo "可用内存: ${AVAILABLE_MEM}MB"

# 如果内存小于 1GB，创建交换文件
if [ "$TOTAL_MEM" -lt 1024 ]; then
    echo ""
    echo "⚠️  检测到内存不足 (< 1GB)，建议创建交换文件"
    read -p "是否创建 2GB 交换文件? (y/n): " create_swap
    
    if [[ $create_swap =~ ^[Yy]$ ]]; then
        echo "📁 创建 2GB 交换文件..."
        sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo "✅ 交换文件创建完成"
        
        # 显示新的内存状态
        echo "📊 更新后的内存状态:"
        free -h
    fi
fi

echo ""
echo "🧹 清理旧的安装文件..."
rm -rf node_modules package-lock.json
npm cache clean --force

echo ""
echo "📦 使用低内存模式安装依赖..."

# 设置 Node.js 环境变量
export NODE_OPTIONS="--max_old_space_size=512"
export NPM_CONFIG_PROGRESS=false
export NPM_CONFIG_LOGLEVEL=error

# 使用保守的 npm 参数
npm install \
    --no-optional \
    --no-audit \
    --no-fund \
    --legacy-peer-deps \
    --prefer-offline \
    --no-progress \
    --silent

if [ $? -eq 0 ]; then
    echo "✅ 依赖安装成功"
    
    echo ""
    echo "🔨 构建项目..."
    export NODE_OPTIONS="--max_old_space_size=1024"
    npm run build
    
    if [ $? -eq 0 ]; then
        echo "✅ 构建成功！"
        echo ""
        echo "📂 构建产物:"
        ls -la out/renderer/ | head -10
        echo ""
        echo "🎉 可以继续执行部署脚本:"
        echo "   ./deploy/deploy-debian.sh"
    else
        echo "❌ 构建失败"
        exit 1
    fi
else
    echo "❌ 依赖安装失败"
    echo ""
    echo "💡 建议尝试以下方法:"
    echo "1. 增加服务器内存"
    echo "2. 使用更大的交换文件:"
    echo "   sudo dd if=/dev/zero of=/swapfile bs=1M count=4096"
    echo "   sudo chmod 600 /swapfile"
    echo "   sudo mkswap /swapfile"
    echo "   sudo swapon /swapfile"
    echo "3. 分批安装依赖"
    exit 1
fi

echo ""
echo "🔧 内存优化提示:"
echo "- 如果仍然遇到内存问题，可以考虑:"
echo "  1. 关闭其他不必要的服务"
echo "  2. 升级服务器配置"
echo "  3. 使用预构建的 Docker 镜像"
