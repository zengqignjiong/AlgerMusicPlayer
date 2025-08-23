#!/bin/bash
# fix-nginx-path.sh - 修复 Nginx 部署路径问题

echo "🔧 修复 Nginx 部署路径问题"
echo "=========================="

# 检查当前位置
echo "📍 当前目录: $(pwd)"

# 确保在项目根目录
if [ ! -f "package.json" ]; then
    echo "❌ 当前不在项目根目录"
    echo "💡 请确保在包含 package.json 的目录运行此脚本"
    exit 1
fi

PROJECT_ROOT=$(pwd)
echo "📂 项目根目录: $PROJECT_ROOT"

# 检查 nginx 配置目录
NGINX_DIR="$PROJECT_ROOT/deploy/nginx"
if [ ! -d "$NGINX_DIR" ]; then
    echo "❌ Nginx 配置目录不存在: $NGINX_DIR"
    echo "📁 deploy 目录内容:"
    ls -la deploy/
    exit 1
fi

echo "✅ 找到 Nginx 配置目录: $NGINX_DIR"

# 进入 nginx 配置目录
cd "$NGINX_DIR" || exit 1
echo "📂 当前目录: $(pwd)"

# 检查必要文件
echo "📋 检查 Nginx 配置文件..."
if [ ! -f "docker-compose-nginx.yml" ]; then
    echo "❌ 缺少 docker-compose-nginx.yml"
    exit 1
fi

if [ ! -f "nginx.conf" ]; then
    echo "❌ 缺少 nginx.conf"
    exit 1
fi

if [ ! -d "conf" ] || [ ! -f "conf/music.conf" ]; then
    echo "❌ 缺少 conf/music.conf"
    exit 1
fi

echo "✅ 所有配置文件存在"

# 更新 nginx 配置中的 API 端口
echo "🔧 更新 Nginx 配置中的 API 端口..."
sed -i "s/127\.0\.0\.1:30488/127.0.0.1:30488/g" conf/music.conf

# 确保日志目录存在
echo "📁 创建日志目录..."
mkdir -p logs
touch logs/access.log logs/error.log

# 停止现有容器
echo "🛑 停止现有 Nginx 容器..."
docker-compose -f docker-compose-nginx.yml down 2>/dev/null || true

# 启动 nginx 容器
echo "🚀 启动 Nginx 容器..."
docker-compose -f docker-compose-nginx.yml up -d

if [ $? -eq 0 ]; then
    echo "✅ Nginx 部署完成"
    echo ""
    echo "📋 容器状态:"
    docker-compose -f docker-compose-nginx.yml ps
    echo ""
    echo "🌐 访问地址:"
    echo "   http://localhost:80"
    echo "   http://$(hostname -I | awk '{print $1}'):80"
    echo ""
    echo "🎵 API 地址:"
    echo "   http://localhost:30488"
    echo "   http://$(hostname -I | awk '{print $1}'):30488"
else
    echo "❌ Nginx 启动失败"
    echo ""
    echo "📋 查看错误日志:"
    docker-compose -f docker-compose-nginx.yml logs
    exit 1
fi

echo ""
echo "🎉 修复完成！"
echo ""
echo "📋 后续操作:"
echo "1. 测试前端: curl http://localhost:80"
echo "2. 测试 API: curl http://localhost:30488"
echo "3. 查看日志: docker-compose -f docker-compose-nginx.yml logs -f"
