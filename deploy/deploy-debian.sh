#!/bin/bash
# deploy-debian.sh - AlgerMusicPlayer Debian 部署脚本
# 支持 Docker 容器化部署，快速、可靠、易维护

set -e  # 遇到错误立即退出

# 配置变量
DEPLOY_DIR="/opt/AlgerMusicPlayer"
PROJECT_NAME="AlgerMusicPlayer"
NETEASE_API_PORT="30488"
WEB_PORT="80"
DOMAIN="music.finderhk.com"  # 可根据实际域名修改

echo "🚀 开始部署 AlgerMusicPlayer 到 Debian 服务器..."
echo "部署目录: $DEPLOY_DIR"
echo "项目名称: $PROJECT_NAME"
echo "================================="

# 检查运行环境
check_requirements() {
    echo "📋 检查系统环境..."
    
    # 检查是否为 root 用户或有 sudo 权限
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        echo "❌ 需要 root 权限或 sudo 权限"
        exit 1
    fi
    
    # 检查系统是否为 Debian/Ubuntu
    if ! command -v apt-get &> /dev/null; then
        echo "❌ 此脚本仅支持 Debian/Ubuntu 系统"
        exit 1
    fi
    
    echo "✅ 系统环境检查通过"
}

# 安装必需的软件
install_dependencies() {
    echo "📦 安装系统依赖..."
    
    sudo apt-get update
    
    # 安装 Docker
    if ! command -v docker &> /dev/null; then
        echo "🐳 安装 Docker..."
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl enable docker
        sudo systemctl start docker
        echo "✅ Docker 安装完成"
    else
        echo "✅ Docker 已安装"
    fi
    
    # 安装 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo "🔧 安装 Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "✅ Docker Compose 安装完成"
    else
        echo "✅ Docker Compose 已安装"
    fi
    
    # 安装 Node.js (用于构建前端)
    if ! command -v node &> /dev/null; then
        echo "📦 安装 Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        echo "✅ Node.js 安装完成"
    else
        echo "✅ Node.js 已安装 (版本: $(node --version))"
    fi
    
    # 安装 Git
    if ! command -v git &> /dev/null; then
        echo "📦 安装 Git..."
        sudo apt-get install -y git
        echo "✅ Git 安装完成"
    else
        echo "✅ Git 已安装"
    fi
}

# 准备部署目录
prepare_deploy_directory() {
    echo "📁 准备部署目录..."
    
    # 获取当前目录作为实际的部署目录
    ACTUAL_DEPLOY_DIR=$(pwd)
    echo "📂 实际部署目录: $ACTUAL_DEPLOY_DIR"
    
    # 检查是否在项目根目录
    if [ ! -f "package.json" ]; then
        echo "❌ 当前目录不是项目根目录"
        echo "💡 请在包含 package.json 的目录运行此脚本"
        exit 1
    fi
    
    # 确保有写权限
    if [ ! -w "." ]; then
        echo "⚠️  当前目录无写权限，尝试修复..."
        sudo chown -R $USER:$USER .
    fi
    
    echo "✅ 部署目录准备完成"
}

# 拉取代码并构建前端
build_frontend() {
    echo "🏗️ 构建前端项目..."
    
    # 检查是否在正确的项目目录中运行
    if [ ! -f "package.json" ]; then
        echo "❌ 当前目录 $(pwd) 没有找到项目代码"
        echo "📍 检测到的目录结构:"
        ls -la
        echo ""
        echo "💡 请确认:"
        echo "   1. 代码已正确上传到服务器"
        echo "   2. 在项目根目录运行脚本 (包含 package.json 的目录)"
        echo ""
        echo "🔄 如果代码在其他位置，请:"
        echo "   cd /path/to/your/project"
        echo "   ./deploy/deploy-debian.sh"
        exit 1
    fi
    
    echo "✅ 找到项目文件 package.json"
    echo "📂 当前工作目录: $(pwd)"
    
    # 检查系统内存
    echo "📊 检查系统资源..."
    echo "内存使用情况:"
    free -h
    echo "磁盘空间:"
    df -h /opt
    
    # 安装依赖 (添加内存优化参数)
    echo "📦 安装前端依赖..."
    echo "⚠️  如果内存不足，将使用优化参数..."
    
    # 检查可用内存 (MB)
    AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    echo "可用内存: ${AVAILABLE_MEM}MB"
    
    if [ "$AVAILABLE_MEM" -lt 512 ]; then
        echo "⚠️  内存不足，使用低内存模式安装..."
        # 创建临时交换文件
        if [ ! -f /swapfile ]; then
            echo "📁 创建临时交换文件 (1GB)..."
            sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
        fi
        
        # 使用低内存参数安装
        npm install --no-optional --no-audit --no-fund --max_old_space_size=512
    else
        npm install
    fi
    
    # 检查安装是否成功
    if [ $? -ne 0 ]; then
        echo "❌ npm install 失败，尝试其他方法..."
        echo "🔄 清理缓存后重试..."
        npm cache clean --force
        rm -rf node_modules package-lock.json
        
        # 使用更保守的参数重试
        echo "🔁 使用保守参数重新安装..."
        npm install --no-optional --no-audit --no-fund --legacy-peer-deps
        
        if [ $? -ne 0 ]; then
            echo "❌ npm install 仍然失败，请检查系统资源"
            echo "💡 建议:"
            echo "   1. 检查磁盘空间是否充足"
            echo "   2. 增加服务器内存 (建议至少 1GB)"
            echo "   3. 手动创建更大的交换文件"
            exit 1
        fi
    fi
    
    echo "✅ 依赖安装完成"
    
    # 构建项目
    echo "🔨 构建前端项目..."
    # 设置 Node.js 内存限制
    export NODE_OPTIONS="--max_old_space_size=1024"
    npm run build
    
    # 验证构建产物
    if [ ! -d "out/renderer" ] || [ ! -f "out/renderer/index.html" ]; then
        echo "❌ 前端构建失败，缺少构建产物"
        exit 1
    fi
    
    echo "✅ 前端构建完成"
    ls -la out/renderer/
}

# 部署网易云音乐 API
deploy_netease_api() {
    echo "🎵 部署网易云音乐 API..."
    
    # 在当前项目目录中创建 API 目录
    mkdir -p netease-api
    cd netease-api
    
    # 创建 Dockerfile (使用 HTTPS 克隆，更可靠)
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# 克隆网易云音乐 API (使用 HTTPS 方式，避免 SSH 密钥问题)
RUN apk add --no-cache git && \
    git clone https://github.com/zengqignjiong/neteasecloudmusicapi.git . && \
    npm ci --omit=dev --ignore-scripts

EXPOSE 3000

CMD ["node", "app.js"]
EOF
    
    # 创建 docker-compose 配置
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  netease-api:
    build: .
    container_name: netease-api
    ports:
      - "$NETEASE_API_PORT:3000"
    restart: always
    environment:
      - NODE_ENV=production
    networks:
      - alger-network

networks:
  alger-network:
    driver: bridge
EOF
    
    # 构建并启动服务
    docker-compose down 2>/dev/null || true
    docker-compose build
    docker-compose up -d
    
    echo "✅ 网易云音乐 API 部署完成 (端口: $NETEASE_API_PORT)"
}

# 部署 Nginx 和前端
deploy_nginx() {
    echo "🌐 部署 Nginx 和前端..."
    
    # 回到项目根目录，然后进入 nginx 配置目录
    cd "$(dirname "${BASH_SOURCE[0]}")"/../  # 回到项目根目录
    cd deploy/nginx
    
    # 更新 nginx 配置中的 API 端口
    sed -i "s/127\.0\.0\.1:30488/127.0.0.1:$NETEASE_API_PORT/g" conf/music.conf
    
    # 确保日志目录存在
    mkdir -p logs
    touch logs/access.log logs/error.log
    
    # 停止并启动 nginx 容器
    docker-compose -f docker-compose-nginx.yml down 2>/dev/null || true
    docker-compose -f docker-compose-nginx.yml up -d
    
    echo "✅ Nginx 部署完成 (端口: $WEB_PORT)"
}

# 清理临时文件
cleanup_temp_files() {
    echo "🧹 清理临时文件..."
    
    # 如果创建了临时交换文件，则关闭并删除
    if [ -f /swapfile ]; then
        echo "🗑️  清理临时交换文件..."
        sudo swapoff /swapfile 2>/dev/null || true
        sudo rm -f /swapfile
    fi
    
    # 清理 npm 缓存
    npm cache clean --force 2>/dev/null || true
    
    echo "✅ 清理完成"
}

# 配置防火墙（可选）
configure_firewall() {
    echo "🔒 配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow $WEB_PORT/tcp
        sudo ufw allow $NETEASE_API_PORT/tcp
        echo "✅ 防火墙规则已添加"
    else
        echo "ℹ️ 未检测到 ufw，跳过防火墙配置"
    fi
}

# 显示部署结果
show_deployment_info() {
    echo ""
    echo "🎉 部署完成！"
    echo "================================="
    echo "📱 前端访问地址:"
    echo "   http://localhost:$WEB_PORT"
    echo "   http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    if [ "$DOMAIN" != "music.finderhk.com" ] || command -v dig &> /dev/null && dig +short $DOMAIN &> /dev/null; then
        echo "   http://$DOMAIN"
    fi
    echo ""
    echo "🎵 网易云音乐 API:"
    echo "   http://localhost:$NETEASE_API_PORT"
    echo "   http://$(hostname -I | awk '{print $1}'):$NETEASE_API_PORT"
    echo ""
    echo "📂 部署目录: $(pwd)"
    echo "🐳 Docker 容器状态:"
    docker ps --filter "name=nginx" --filter "name=netease-api" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "📋 管理命令:"
    echo "   查看日志: docker-compose -f $(pwd)/deploy/nginx/docker-compose-nginx.yml logs -f"
    echo "   重启服务: cd $(pwd) && ./deploy/deploy-debian.sh restart"
    echo "   停止服务: cd $(pwd) && ./deploy/deploy-debian.sh stop"
    echo ""
}

# 重启服务
restart_services() {
    echo "🔄 重启服务..."
    
    # 获取项目根目录
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    cd "$PROJECT_ROOT/netease-api"
    docker-compose restart
    
    cd "$PROJECT_ROOT/deploy/nginx"
    docker-compose -f docker-compose-nginx.yml restart
    
    echo "✅ 服务重启完成"
    show_deployment_info
}

# 停止服务
stop_services() {
    echo "🛑 停止服务..."
    
    # 获取项目根目录
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    cd "$PROJECT_ROOT/netease-api"
    docker-compose down
    
    cd "$PROJECT_ROOT/deploy/nginx"
    docker-compose -f docker-compose-nginx.yml down
    
    echo "✅ 服务已停止"
}

# 主函数
main() {
    case "${1:-deploy}" in
        "deploy")
            check_requirements
            install_dependencies
            prepare_deploy_directory
            build_frontend
            deploy_netease_api
            deploy_nginx
            configure_firewall
            cleanup_temp_files
            show_deployment_info
            ;;
        "restart")
            restart_services
            ;;
        "stop")
            stop_services
            ;;
        "status")
            echo "🐳 Docker 容器状态:"
            docker ps --filter "name=nginx" --filter "name=netease-api" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            ;;
        *)
            echo "用法: $0 [deploy|restart|stop|status]"
            echo "  deploy  - 完整部署 (默认)"
            echo "  restart - 重启服务"
            echo "  stop    - 停止服务"
            echo "  status  - 查看状态"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
