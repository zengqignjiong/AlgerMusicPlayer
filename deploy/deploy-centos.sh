#!/bin/bash

# AlgerMusicPlayer CentOS 部署脚本
# 适用于 CentOS 7/8/9 和 RHEL 系统

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查并优化内存
check_and_optimize_memory() {
    log_info "检查系统内存..."
    
    # 获取内存信息
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    SWAP_TOTAL=$(free -m | awk 'NR==3{printf "%.0f", $2}')
    
    log_info "总内存: ${TOTAL_MEM}MB, 可用内存: ${AVAILABLE_MEM}MB, Swap: ${SWAP_TOTAL}MB"
    
    # 如果可用内存小于1GB，尝试优化
    if [ "$AVAILABLE_MEM" -lt 1024 ]; then
        log_warn "可用内存不足1GB，正在优化内存..."
        
        # 清理缓存
        sync
        echo 3 > /proc/sys/vm/drop_caches
        
        # 如果没有swap或swap太小，创建临时swap
        if [ "$SWAP_TOTAL" -lt 2048 ]; then
            log_info "创建临时swap文件以增加虚拟内存..."
            
            # 创建2GB swap文件
            if ! dd if=/dev/zero of=/tmp/swapfile bs=1M count=2048 2>/dev/null; then
                log_warn "创建swap文件失败，继续执行"
            else
                chmod 600 /tmp/swapfile
                if mkswap /tmp/swapfile 2>/dev/null && swapon /tmp/swapfile 2>/dev/null; then
                    log_info "✅ 临时swap已启用 (+2GB)"
                else
                    log_warn "启用swap失败，删除临时文件"
                    rm -f /tmp/swapfile
                fi
            fi
        fi
        
        # 重新检查内存
        AVAILABLE_MEM_NEW=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        log_info "优化后可用内存: ${AVAILABLE_MEM_NEW}MB"
    fi
    
    # 设置Node.js内存限制
    export NODE_OPTIONS="--max-old-space-size=1024"
    log_info "设置Node.js内存限制: 1024MB"
}

# 清理临时资源
cleanup_temp_resources() {
    log_info "清理临时资源..."
    
    # 关闭临时swap
    if [ -f /tmp/swapfile ]; then
        swapoff /tmp/swapfile 2>/dev/null || true
        rm -f /tmp/swapfile
        log_info "临时swap已清理"
    fi
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检测CentOS版本
detect_centos_version() {
    if [ -f /etc/redhat-release ]; then
        CENTOS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release 2>/dev/null || echo "unknown")
        if [ "$CENTOS_VERSION" = "unknown" ]; then
            # 尝试从release文件中获取版本
            CENTOS_VERSION=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
        fi
        log_info "检测到 CentOS/RHEL 版本: $CENTOS_VERSION"
    else
        log_error "不支持的系统，此脚本仅适用于CentOS/RHEL"
        exit 1
    fi
}

# 检查并安装Node.js
check_and_install_nodejs() {
    log_info "检查Node.js版本..."
    
    # 检查Node.js是否已安装
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | sed 's/v//')
        MAJOR_VERSION=$(echo $NODE_VERSION | cut -d. -f1)
        log_info "当前Node.js版本: v$NODE_VERSION"
        
        if [ "$MAJOR_VERSION" -ge 20 ]; then
            log_info "✅ Node.js版本满足要求 (>= 20)"
            return 0
        else
            log_warn "⚠️  Node.js版本过低 (当前: v$NODE_VERSION, 需要: >= 20)"
            log_info "开始安装最新版Node.js..."
        fi
    else
        log_info "未检测到Node.js，开始安装最新版..."
    fi
    
    # 卸载旧版本Node.js
    log_info "清理旧版本Node.js..."
    yum remove -y nodejs npm || true
    rm -rf /usr/local/node* /usr/local/bin/node /usr/local/bin/npm || true
    
    # 使用NodeSource官方仓库安装最新LTS版本
    log_info "添加NodeSource仓库..."
    curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
    
    log_info "安装最新版Node.js..."
    yum install -y nodejs
    
    # 验证安装
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        NEW_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)
        log_info "✅ Node.js安装成功:"
        log_info "   Node.js版本: $NEW_VERSION"
        log_info "   npm版本: v$NPM_VERSION"
        
        # 再次检查版本是否符合要求
        MAJOR_VERSION=$(echo $NEW_VERSION | sed 's/v//' | cut -d. -f1)
        if [ "$MAJOR_VERSION" -ge 20 ]; then
            log_info "✅ Node.js版本验证通过"
        else
            log_error "❌ 安装的Node.js版本仍然不满足要求"
            exit 1
        fi
    else
        log_error "❌ Node.js安装失败"
        exit 1
    fi
}

# 安装基础依赖
install_dependencies() {
    log_info "更新系统包..."
    yum update -y

    log_info "安装基础依赖..."
    yum install -y curl wget git unzip net-tools

    # 安装EPEL仓库
    if ! rpm -qa | grep -q epel-release; then
        log_info "安装EPEL仓库..."
        yum install -y epel-release
    fi
}

# 拉取项目代码
clone_project() {
    log_info "拉取项目代码..."
    
    PROJECT_DIR="/opt/AlgerMusicPlayer"
    NETEASE_DIR="/opt/NeteaseCloudMusicApi"
    
    # 创建目录
    mkdir -p /opt
    
    # 拉取主项目
    if [ -d "$PROJECT_DIR" ]; then
        log_info "项目目录已存在，尝试更新代码..."
        cd "$PROJECT_DIR"
        
        # 设置git配置避免警告
        git config pull.rebase false 2>/dev/null || true
        
        # 尝试更新代码，失败时继续执行
        if git pull 2>/dev/null; then
            log_info "✅ 主项目代码更新成功"
        else
            log_warn "⚠️  主项目代码更新失败，继续使用现有代码"
        fi
    else
        log_info "克隆主项目..."
        if git clone git@github.com:zengqignjiong/AlgerMusicPlayer.git "$PROJECT_DIR" 2>/dev/null; then
            log_info "✅ 主项目克隆成功"
        else
            log_error "❌ 主项目克隆失败，请检查网络连接或手动下载代码"
            exit 1
        fi
    fi
    
    # 拉取API项目
    if [ -d "$NETEASE_DIR" ]; then
        log_info "API项目目录已存在，尝试更新代码..."
        cd "$NETEASE_DIR"
        
        # 设置git配置避免警告
        git config pull.rebase false 2>/dev/null || true
        
        # 尝试更新代码，失败时继续执行
        if git pull 2>/dev/null; then
            log_info "✅ API项目代码更新成功"
        else
            log_warn "⚠️  API项目代码更新失败，继续使用现有代码"
        fi
    else
        log_info "克隆API项目..."
        if git clone https://github.com/zengqignjiong/neteasecloudmusicapi.git "$NETEASE_DIR" 2>/dev/null; then
            log_info "✅ API项目克隆成功"
        else
            log_error "❌ API项目克隆失败，请检查网络连接或手动下载代码到 $NETEASE_DIR"
            exit 1
        fi
    fi
}

# 构建API服务
build_api_service() {
    log_info "构建API服务..."
    
    cd /opt/NeteaseCloudMusicApi
    
    # 显示当前运行的容器，避免冲突
    log_info "当前运行的Docker容器："
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true
    
    # 检查端口占用情况
    if netstat -tulpn | grep -q ":3000 "; then
        log_warn "端口3000已被占用，请检查是否有其他API服务在运行"
        netstat -tulpn | grep ":3000 "
        read -p "是否继续部署？现有服务可能会冲突 (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消API服务部署"
            return
        fi
    fi
    
    # Node.js和npm现在应该已经正确安装
    export PATH=$PATH:/usr/bin:/usr/local/bin
    
    # 验证npm和node可用性
    if ! command -v npm &> /dev/null || ! command -v node &> /dev/null; then
        log_error "npm或node命令未找到，Node.js安装可能有问题"
        log_info "当前PATH: $PATH"
        exit 1
    fi
    
    NPM_CMD="npm"
    NODE_CMD="node"
    
    log_info "使用npm版本: $($NPM_CMD --version)"
    log_info "使用node版本: $($NODE_CMD --version)"
    
    # 智能安装依赖 - 检查是否有package-lock.json
    if [ -f "package-lock.json" ]; then
        log_info "发现package-lock.json，使用npm ci安装依赖..."
        # 使用内存优化选项
        $NPM_CMD ci --omit=dev --ignore-scripts --prefer-offline --no-audit --no-fund
    else
        log_info "未发现package-lock.json，使用npm install安装依赖..."
        # 使用内存优化选项
        $NPM_CMD install --production --ignore-scripts --prefer-offline --no-audit --no-fund
    fi
    
    # 先停止并删除旧容器（如果存在）
    log_info "检查并删除旧的netease-api容器..."
    if docker ps -a --format "{{.Names}}" | grep -q "^netease-api$"; then
        log_info "发现旧的netease-api容器，正在停止并删除..."
        docker stop netease-api 2>/dev/null || true
        docker rm netease-api 2>/dev/null || true
        log_info "旧容器已删除"
    else
        log_info "未发现旧的netease-api容器"
    fi
    
    # 再删除旧的Docker镜像
    log_info "检查并删除旧的netease-api镜像..."
    if docker images | grep -q "netease-api"; then
        log_info "发现旧的netease-api镜像，正在删除..."
        docker rmi netease-api 2>/dev/null || log_warn "删除旧镜像失败，可能正在被使用"
    else
        log_info "未发现旧的netease-api镜像"
    fi
    
    # 构建Docker镜像
    log_info "构建新的netease-api镜像..."
    docker build -t netease-api .
    
    # 启动API服务（使用固定容器名）
    log_info "启动新的netease-api容器..."
    docker run -d --name "netease-api" --restart=unless-stopped -p 3000:3000 netease-api
    
    log_info "API服务已启动，容器名: netease-api"
}

# 构建前端服务
build_frontend() {
    log_info "构建前端服务..."
    
    cd /opt/AlgerMusicPlayer
    
    # 显示当前运行的容器
    log_info "当前运行的Docker容器："
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true
    
    # 检查端口占用情况
    if netstat -tulpn | grep -q ":3080 "; then
        log_warn "端口3080已被占用，请检查是否有其他Web服务在运行"
        netstat -tulpn | grep ":3080 "
        read -p "是否继续部署？现有服务可能会冲突 (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消前端服务部署"
            return
        fi
    fi
    
    # Node.js和npm现在应该已经正确安装
    export PATH=$PATH:/usr/bin:/usr/local/bin
    
    # 验证npm和node可用性
    if ! command -v npm &> /dev/null || ! command -v node &> /dev/null; then
        log_error "npm或node命令未找到，Node.js安装可能有问题"
        log_info "当前PATH: $PATH"
        exit 1
    fi
    
    NPM_CMD="npm"
    NODE_CMD="node"
    
    log_info "使用npm版本: $($NPM_CMD --version)"
    log_info "使用node版本: $($NODE_CMD --version)"
    
    # 智能安装依赖 - 检查是否有package-lock.json
    if [ -f "package-lock.json" ]; then
        log_info "发现package-lock.json，使用npm ci安装依赖..."
        # 使用内存优化选项
        $NPM_CMD ci --prefer-offline --no-audit --no-fund
    else
        log_info "未发现package-lock.json，使用npm install安装依赖..."
        # 使用内存优化选项
        $NPM_CMD install --prefer-offline --no-audit --no-fund
    fi
    
    # 构建项目
    log_info "构建前端项目..."
    # 使用vite进行Web构建，而不是electron-vite
    npx vite build
    
    # 适配现有nginx配置目录
    NGINX_VHOST_DIR="/usr/local/nginx/conf/vhost"
    
    if [ -d "$NGINX_VHOST_DIR" ]; then
        log_info "检测到现有nginx配置目录: $NGINX_VHOST_DIR"
        NGINX_CONFIG_FILE="$NGINX_VHOST_DIR/algermusic.conf"
    else
        log_warn "未找到 $NGINX_VHOST_DIR，使用默认配置目录"
        mkdir -p /etc/nginx/conf.d
        NGINX_CONFIG_FILE="/etc/nginx/conf.d/algermusic.conf"
    fi
    
    log_info "创建nginx配置文件: $NGINX_CONFIG_FILE"
    
    cat > "$NGINX_CONFIG_FILE" << 'EOF'
server {
    listen 3080;
    server_name _;
    root /opt/AlgerMusicPlayer/dist;
    index index.html;

    # Gzip压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;

    # 静态文件缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API代理
    location /api/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 前端路由
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

    # 使用现有的nginx，不进行安装操作
    log_info "检查现有nginx服务状态..."
    
    # 检查nginx进程
    if pgrep nginx > /dev/null; then
        log_info "nginx进程正在运行"
        # 尝试重载配置
        if [ -f /usr/local/nginx/sbin/nginx ]; then
            log_info "使用 /usr/local/nginx/sbin/nginx 重载配置"
            /usr/local/nginx/sbin/nginx -s reload
        elif command -v nginx &> /dev/null; then
            log_info "使用系统nginx重载配置"
            nginx -s reload
        else
            log_warn "无法找到nginx可执行文件，请手动重载nginx配置"
        fi
    else
        log_warn "nginx未运行，请手动启动nginx服务"
        log_info "nginx配置文件已创建: $NGINX_CONFIG_FILE"
    fi
    
    log_info "前端服务已部署，使用现有nginx"
}

# 主函数
main() {
    log_info "开始CentOS部署..."
    
    # 设置清理函数
    trap cleanup_temp_resources EXIT
    
    check_root
    detect_centos_version
    check_and_optimize_memory
    install_dependencies
    check_and_install_nodejs
    clone_project
    build_api_service
    build_frontend
    
    log_info "=================================="
    log_info "部署完成！"
    log_info "前端访问地址: http://$(hostname -I | awk '{print $1}'):3080"
    log_info "API服务地址: http://$(hostname -I | awk '{print $1}'):3000"
    log_info "=================================="
    
    # 手动清理资源
    cleanup_temp_resources
}

# 执行主函数
main "$@"
