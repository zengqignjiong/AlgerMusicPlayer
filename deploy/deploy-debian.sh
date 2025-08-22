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
    
    sudo mkdir -p $DEPLOY_DIR
    sudo chown -R $USER:$USER $DEPLOY_DIR
    
    # 如果目录已存在，备份旧版本
    if [ -d "$DEPLOY_DIR/src" ]; then
        echo "📦 备份旧版本..."
        sudo mv $DEPLOY_DIR $DEPLOY_DIR.backup.$(date +%Y%m%d_%H%M%S)
        sudo mkdir -p $DEPLOY_DIR
        sudo chown -R $USER:$USER $DEPLOY_DIR
    fi
    
    echo "✅ 部署目录准备完成"
}

# 拉取代码并构建前端
build_frontend() {
    echo "🏗️ 构建前端项目..."
    
    cd $DEPLOY_DIR
    
    # 如果当前目录已有代码，则直接使用
    if [ ! -f "package.json" ]; then
        echo "❌ 当前目录没有找到项目代码，请先将代码上传到 $DEPLOY_DIR"
        echo "   可以使用 git clone 或直接上传项目文件"
        exit 1
    fi
    
    # 安装依赖
    echo "📦 安装前端依赖..."
    npm install
    
    # 构建项目
    echo "🔨 构建前端项目..."
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
    
    cd $DEPLOY_DIR
    
    # 创建 API 目录
    mkdir -p netease-api
    cd netease-api
    
    # 创建 Dockerfile
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# 克隆网易云音乐 API
RUN apk add --no-cache git && \
    git clone https://github.com/Binaryify/NeteaseCloudMusicApi.git . && \
    npm install

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
    
    cd $DEPLOY_DIR/deploy/nginx
    
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
    echo "📂 部署目录: $DEPLOY_DIR"
    echo "🐳 Docker 容器状态:"
    docker ps --filter "name=nginx" --filter "name=netease-api" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "📋 管理命令:"
    echo "   查看日志: docker-compose -f $DEPLOY_DIR/deploy/nginx/docker-compose-nginx.yml logs -f"
    echo "   重启服务: cd $DEPLOY_DIR && ./deploy-debian.sh restart"
    echo "   停止服务: cd $DEPLOY_DIR && ./deploy-debian.sh stop"
    echo ""
}

# 重启服务
restart_services() {
    echo "🔄 重启服务..."
    
    cd $DEPLOY_DIR/netease-api
    docker-compose restart
    
    cd $DEPLOY_DIR/deploy/nginx
    docker-compose -f docker-compose-nginx.yml restart
    
    echo "✅ 服务重启完成"
    show_deployment_info
}

# 停止服务
stop_services() {
    echo "🛑 停止服务..."
    
    cd $DEPLOY_DIR/netease-api
    docker-compose down
    
    cd $DEPLOY_DIR/deploy/nginx
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
