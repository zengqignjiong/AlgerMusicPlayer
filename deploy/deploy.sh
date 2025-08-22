#!/bin/bash
# deploy.sh - 部署脚本入口
# 此脚本用于选择合适的部署方式

echo "🚀 AlgerMusicPlayer 部署脚本"
echo "================================="
echo ""
echo "请选择部署方式:"
echo ""
echo "1. Debian/Ubuntu 服务器部署 (推荐)"
echo "   - 使用 Docker 容器化部署"
echo "   - 自动安装所有依赖"
echo "   - 适合生产环境"
echo ""
echo "2. 传统方式部署 (旧版本)"
echo "   - 使用 PM2 管理进程"
echo "   - 需要手动配置环境"
echo ""

read -p "请输入选择 (1 或 2): " choice

case $choice in
    1)
        echo "使用 Debian/Ubuntu Docker 部署方式..."
        if [ -f "deploy/deploy-debian.sh" ]; then
            chmod +x deploy/deploy-debian.sh
            exec ./deploy/deploy-debian.sh "$@"
        else
            echo "❌ 找不到 deploy-debian.sh 脚本"
            exit 1
        fi
        ;;
    2)
        echo "使用传统部署方式..."
        echo "⚠️  警告: 传统部署方式已过时，建议使用 Docker 部署"
        read -p "确认继续? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            # 执行传统部署逻辑
            deploy_legacy
        else
            echo "已取消部署"
            exit 0
        fi
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

# 传统部署方式 (保留原有逻辑)
deploy_legacy() {
    echo "开始传统方式部署..."
    
    # 设置 /opt/AlgerMusicPlayer 目录权限
    echo "设置部署目录权限..."
    sudo mkdir -p /opt/AlgerMusicPlayer
    sudo chown -R $USER:$USER /opt/AlgerMusicPlayer
    sudo chmod -R 755 /opt/AlgerMusicPlayer
    
    echo "⚠️  传统部署需要手动完成以下步骤:"
    echo "1. 安装 Node.js 18+"
    echo "2. 安装 PM2: npm install -g pm2"
    echo "3. 克隆网易云 API: git clone https://github.com/Binaryify/NeteaseCloudMusicApi.git"
    echo "4. 安装依赖: npm install"
    echo "5. 启动服务: pm2 start app.js --name netease-api"
    echo "6. 构建前端: npm run build"
    echo "7. 配置 Nginx"
    echo ""
    echo "详细步骤请参考 deploy/README-DEPLOY.md"
}