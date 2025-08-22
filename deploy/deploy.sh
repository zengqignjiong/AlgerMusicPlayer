#!/bin/bash
# deploy.sh

echo "开始部署 Finder 音乐服务..."

# 设置 /data/AlgerMusicPlayer 目录权限，允许 SFTP 读写
echo "设置 /data/AlgerMusicPlayer 目录 SFTP 权限..."
sudo mkdir -p /data/AlgerMusicPlayer
sudo chown -R $USER:$USER /data/AlgerMusicPlayer
sudo chmod -R 755 /data/AlgerMusicPlayer

# 如果有 SFTP 用户组，也给予权限
if getent group sftp >/dev/null 2>&1; then
    sudo chgrp -R sftp /data/AlgerMusicPlayer
    sudo chmod -R 775 /data/AlgerMusicPlayer
fi

echo "目录权限设置完成"

# 部署网易云 API
echo "部署网易云 API..."
cd /data
git clone git@github.com:zengqignjiong/neteasecloudmusicapi.git
cd neteasecloudmusicapi
npm install
pm2 start app.js --name "netease-api" -- --port 3000

# 部署音乐解锁 API
echo "部署音乐解锁 API..."
cd /data
mkdir music-unlock-api
cd music-unlock-api
npm init -y
npm install express cors @unblockneteasemusic/server

# 复制音乐解锁服务代码到 music-unlock-server.js
pm2 start music-unlock-server.js --name "music-unlock-api"

# 构建 Finder 前端
echo "构建 Finder 前端..."
cd /data/AlgerMusicPlayer
npm install
npm run build

# 验证构建产物
echo "验证构建产物..."
if [ ! -d "out/renderer" ]; then
    echo "错误：构建产物目录 out/renderer 不存在！"
    exit 1
fi

if [ ! -f "out/renderer/index.html" ]; then
    echo "错误：index.html 文件不存在！"
    exit 1
fi

echo "构建产物验证成功"
ls -la out/renderer/

# 清空nginx日志
echo "清空nginx日志文件..."
sudo truncate -s 0 /data/Nginx/logs/* 2>/dev/null || true

# 部署到 Nginx
# nginx直接访问路径out/renderer/
cd /data/nginx
docker compose -f docker-compose-nginx.yml down
docker compose -f docker-compose-nginx.yml up -d

echo "部署完成！"
echo "网易云 API: https://music.finderhk.com:3000"
echo "音乐解锁 API: https://music.finderhk.com:3001"
echo "Finder 前端: https://music.finderhk.com"