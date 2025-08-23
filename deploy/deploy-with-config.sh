#!/bin/bash
# deploy-with-config.sh - 支持配置文件的部署脚本

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [ -f "$CONFIG_FILE" ]; then
    echo "📋 加载配置文件: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "⚠️  配置文件不存在，使用默认配置"
    # 默认配置
    NETEASE_API_REPO="https://github.com/zengqignjiong/neteasecloudmusicapi.git"
    NETEASE_API_PORT="30488"
    WEB_PORT="80"
    DOMAIN="music.finderhk.com"
    NODE_VERSION="18-alpine"
fi

echo "🚀 使用配置部署 AlgerMusicPlayer"
echo "================================="
echo "📍 网易云 API 仓库: $NETEASE_API_REPO"
echo "📍 API 端口: $NETEASE_API_PORT"
echo "📍 Web 端口: $WEB_PORT"
echo "📍 域名: $DOMAIN"
echo "================================="

# 生成动态 Dockerfile
generate_dockerfile() {
    cat > netease-api/Dockerfile << EOF
FROM node:${NODE_VERSION:-18-alpine}

WORKDIR /app

# 克隆网易云音乐 API
RUN apk add --no-cache git && \\
    git clone ${NETEASE_API_REPO} . && \\
    npm install --production

EXPOSE 3000

CMD ["node", "app.js"]
EOF
}

# 生成动态 docker-compose 配置
generate_docker_compose() {
    cat > netease-api/docker-compose.yml << EOF
version: '3.8'

services:
  netease-api:
    build: .
    container_name: netease-api
    ports:
      - "${NETEASE_API_PORT}:3000"
    restart: always
    environment:
      - NODE_ENV=production
    networks:
      - ${DOCKER_NETWORK_NAME:-alger-network}

networks:
  ${DOCKER_NETWORK_NAME:-alger-network}:
    driver: bridge
EOF
}

# 部署网易云音乐 API (使用配置)
deploy_netease_api_with_config() {
    echo "🎵 部署网易云音乐 API (使用配置)..."
    
    mkdir -p netease-api
    cd netease-api
    
    # 生成配置文件
    generate_dockerfile
    generate_docker_compose
    
    echo "📄 生成的 Dockerfile:"
    cat Dockerfile
    echo ""
    
    # 构建并启动服务
    docker-compose down 2>/dev/null || true
    docker-compose build
    docker-compose up -d
    
    echo "✅ 网易云音乐 API 部署完成 (端口: $NETEASE_API_PORT)"
}

# 检查配置文件有效性
validate_config() {
    echo "🔍 验证配置..."
    
    if [[ ! "$NETEASE_API_REPO" =~ ^https?:// ]]; then
        echo "❌ 无效的仓库地址: $NETEASE_API_REPO"
        exit 1
    fi
    
    if [[ ! "$NETEASE_API_PORT" =~ ^[0-9]+$ ]] || [ "$NETEASE_API_PORT" -lt 1 ] || [ "$NETEASE_API_PORT" -gt 65535 ]; then
        echo "❌ 无效的端口号: $NETEASE_API_PORT"
        exit 1
    fi
    
    echo "✅ 配置验证通过"
}

# 主函数
main() {
    validate_config
    
    case "${1:-api}" in
        "api")
            deploy_netease_api_with_config
            ;;
        "config")
            echo "📋 当前配置:"
            echo "  API 仓库: $NETEASE_API_REPO"
            echo "  API 端口: $NETEASE_API_PORT"
            echo "  Web 端口: $WEB_PORT"
            echo "  域名: $DOMAIN"
            echo "  Node 版本: $NODE_VERSION"
            ;;
        "edit")
            echo "📝 编辑配置文件:"
            echo "  $CONFIG_FILE"
            echo ""
            echo "💡 修改配置后重新运行部署即可应用"
            ;;
        *)
            echo "用法: $0 [api|config|edit]"
            echo "  api    - 部署 API 服务 (默认)"
            echo "  config - 显示当前配置"
            echo "  edit   - 显示配置文件路径"
            exit 1
            ;;
    esac
}

main "$@"
