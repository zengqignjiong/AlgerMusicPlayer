#!/bin/bash
# fix-husky-error.sh - 修复 husky 安装错误的快速脚本

echo "🔧 修复网易云 API Docker 构建中的 husky 错误"
echo "============================================="

# 检查当前位置
if [ ! -f "package.json" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

echo "📍 当前目录: $(pwd)"

# 停止现有容器
echo "🛑 停止现有的 API 容器..."
if [ -d "netease-api" ]; then
    cd netease-api
    docker-compose down 2>/dev/null || true
    cd ..
fi

# 删除旧的构建文件
echo "🗑️  删除旧的构建文件..."
rm -rf netease-api

# 清理 Docker 构建缓存
echo "🧹 清理 Docker 构建缓存..."
docker builder prune -f

# 创建新的 API 目录和优化的 Dockerfile
echo "📁 创建新的 API 构建配置..."
mkdir -p netease-api
cd netease-api

# 创建优化的 Dockerfile (跳过 husky 安装)
cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# 安装 git
RUN apk add --no-cache git

# 克隆仓库
RUN git clone https://github.com/zengqignjiong/neteasecloudmusicapi.git .

# 创建 .npmrc 跳过脚本执行
RUN echo "ignore-scripts=true" > .npmrc

# 只安装生产依赖，忽略脚本
RUN npm ci --omit=dev --ignore-scripts

# 删除 .npmrc
RUN rm -f .npmrc

EXPOSE 3000

CMD ["node", "app.js"]
EOF

# 创建 docker-compose 配置
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  netease-api:
    build: .
    container_name: netease-api
    ports:
      - "30488:3000"
    restart: always
    environment:
      - NODE_ENV=production
    networks:
      - alger-network

networks:
  alger-network:
    driver: bridge
EOF

echo "✅ 配置文件创建完成"
echo ""
echo "📄 新的 Dockerfile 内容:"
cat Dockerfile
echo ""

# 构建并启动
echo "🏗️  开始构建 API 服务..."
docker-compose build --no-cache

if [ $? -eq 0 ]; then
    echo "✅ API 服务构建成功"
    echo "🚀 启动 API 服务..."
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        echo "✅ API 服务启动成功"
        echo ""
        echo "📋 服务状态:"
        docker-compose ps
        echo ""
        echo "🌐 API 访问地址:"
        echo "   http://localhost:30488"
        echo "   http://$(hostname -I | awk '{print $1}'):30488"
    else
        echo "❌ API 服务启动失败"
        exit 1
    fi
else
    echo "❌ API 服务构建失败"
    echo ""
    echo "💡 建议检查:"
    echo "1. 网络连接是否正常"
    echo "2. GitHub 仓库是否可访问"
    echo "3. Docker 是否有足够空间"
    exit 1
fi

echo ""
echo "🎉 修复完成！"
echo ""
echo "📋 后续操作:"
echo "1. 测试 API: curl http://localhost:30488"
echo "2. 查看日志: docker-compose logs -f"
echo "3. 继续部署前端: cd .. && ./deploy/deploy-debian.sh"
