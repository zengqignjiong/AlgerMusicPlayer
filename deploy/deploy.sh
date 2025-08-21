#!/bin/bash
# deploy.sh

echo "开始部署 Finder 音乐服务..."

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

# 部署到 Nginx
# nginx直接访问路径out/renderer/
cd  /data/Nginx
docker compose -f docker-compose-nginx.yml down
docker compose -f docker-compose-nginx.yml up -d

echo "部署完成！"
echo "网易云 API: https://music.finderhk.com:3000"
echo "音乐解锁 API: https://music.finderhk.com:3001"
echo "Finder 前端: https://music.finderhk.com"