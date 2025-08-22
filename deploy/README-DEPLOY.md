# AlgerMusicPlayer Debian 部署指南

## 概述

这个部署脚本支持在 Debian/Ubuntu 服务器上快速部署 AlgerMusicPlayer 项目，使用 Docker 容器化方案确保环境一致性和易维护性。

## 部署文件结构

```
deploy/
├── deploy-debian.sh      # 主要部署脚本 (推荐使用)
├── deploy.sh            # 部署选择入口脚本
├── quick-deploy.sh      # 快速部署脚本
├── README-DEPLOY.md     # 本文档 - 详细部署指南
└── nginx/               # Nginx 配置目录
    ├── docker-compose-nginx.yml
    ├── nginx.conf
    ├── conf/
    │   └── music.conf
    ├── html/
    └── logs/
```

## 快速部署

### 1. 上传项目代码

将项目代码上传到服务器的 `/opt/AlgerMusicPlayer` 目录：

```bash
# 方式1：使用 Git (推荐)
sudo mkdir -p /opt/AlgerMusicPlayer
sudo chown $USER:$USER /opt/AlgerMusicPlayer
cd /opt/AlgerMusicPlayer
git clone https://github.com/your-username/AlgerMusicPlayer.git .

# 方式2：使用 SCP 上传
scp -r ./AlgerMusicPlayer user@your-server:/opt/

# 方式3：使用 rsync
rsync -avz --progress ./AlgerMusicPlayer/ user@your-server:/opt/AlgerMusicPlayer/
```

### 2. 执行部署脚本

有多种方式执行部署：

**方式一：使用主部署脚本 (推荐)**
```bash
cd /opt/AlgerMusicPlayer
chmod +x deploy/deploy-debian.sh
sudo ./deploy/deploy-debian.sh
```

**方式二：使用快速部署脚本**
```bash
cd /opt/AlgerMusicPlayer/deploy
chmod +x quick-deploy.sh
sudo ./quick-deploy.sh
```

**方式三：使用入口选择脚本**
```bash
cd /opt/AlgerMusicPlayer
chmod +x deploy/deploy.sh
sudo ./deploy/deploy.sh
# 然后选择 "1" 进行 Docker 部署
```

### 3. 验证部署

部署完成后，访问以下地址验证：

- 前端应用：http://your-server-ip
- API 服务：http://your-server-ip:30488

## 部署配置

### 环境变量

在部署前可以修改 `deploy-debian.sh` 中的配置变量：

```bash
DEPLOY_DIR="/opt/AlgerMusicPlayer"    # 部署目录
PROJECT_NAME="AlgerMusicPlayer"       # 项目名称
NETEASE_API_PORT="30488"              # 网易云 API 端口
WEB_PORT="80"                         # Web 服务端口
DOMAIN="music.finderhk.com"           # 域名配置
```

### 域名配置（可选）

如果使用域名访问，需要：

1. 修改 `deploy-debian.sh` 中的 `DOMAIN` 变量
2. 配置 DNS 解析指向服务器 IP
3. 可选：配置 SSL 证书（需要修改 nginx 配置）

## 管理命令

### 查看服务状态

```bash
cd /opt/AlgerMusicPlayer
./deploy/deploy-debian.sh status
```

### 重启服务

```bash
cd /opt/AlgerMusicPlayer
./deploy/deploy-debian.sh restart
```

### 停止服务

```bash
cd /opt/AlgerMusicPlayer
./deploy/deploy-debian.sh stop
```

### 查看日志

```bash
# 查看 nginx 日志
docker-compose -f /opt/AlgerMusicPlayer/deploy/nginx/docker-compose-nginx.yml logs -f

# 查看网易云 API 日志
docker-compose -f /opt/AlgerMusicPlayer/netease-api/docker-compose.yml logs -f
```

## 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 检查端口占用
   sudo netstat -tulpn | grep :80
   sudo netstat -tulpn | grep :30488
   
   # 停止占用端口的服务
   sudo systemctl stop apache2  # 如果 80 端口被 Apache 占用
   ```

2. **Docker 权限问题**
   ```bash
   # 将用户添加到 docker 组
   sudo usermod -aG docker $USER
   # 重新登录或执行
   newgrp docker
   ```

3. **构建失败**
   ```bash
   # 检查 Node.js 版本
   node --version  # 建议 18.x 以上
   
   # 清理缓存重新构建
   cd /opt/AlgerMusicPlayer
   rm -rf node_modules package-lock.json
   npm install
   npm run build
   ```

4. **API 连接失败**
   ```bash
   # 检查网易云 API 服务状态
   docker ps | grep netease-api
   
   # 重启 API 服务
   cd /opt/AlgerMusicPlayer/netease-api
   docker-compose restart
   ```

### 防火墙配置

如果服务器开启了防火墙，需要开放相应端口：

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 80/tcp
sudo ufw allow 30488/tcp

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=30488/tcp
sudo firewall-cmd --reload
```

## 性能优化

### 1. 调整 Nginx 配置

编辑 `deploy/nginx/nginx.conf`：

```nginx
worker_processes auto;
worker_connections 1024;

gzip on;
gzip_types text/plain text/css application/javascript application/json;
```

### 2. 配置反向代理缓存

编辑 `deploy/nginx/conf/music.conf`，添加缓存配置：

```nginx
proxy_cache_path /tmp/nginx_cache levels=1:2 keys_zone=my_cache:10m max_size=10g 
                 inactive=60m use_temp_path=off;

location /api/ {
    proxy_cache my_cache;
    proxy_cache_valid 200 10m;
    proxy_cache_key $uri$is_args$args;
    # ... 其他配置
}
```

## 更新部署

当需要更新代码时：

```bash
cd /opt/AlgerMusicPlayer

# 拉取最新代码
git pull origin main

# 重新构建和部署
npm run build
./deploy/deploy-debian.sh restart
```

## 备份和恢复

### 备份

```bash
# 备份整个部署目录
sudo tar -czf alger-music-backup-$(date +%Y%m%d).tar.gz /opt/AlgerMusicPlayer

# 仅备份配置文件
sudo tar -czf alger-config-backup-$(date +%Y%m%d).tar.gz \
    /opt/AlgerMusicPlayer/deploy/nginx/conf \
    /opt/AlgerMusicPlayer/deploy/nginx/nginx.conf
```

### 恢复

```bash
# 停止服务
./deploy/deploy-debian.sh stop

# 恢复文件
sudo tar -xzf alger-music-backup-YYYYMMDD.tar.gz -C /

# 重启服务
./deploy/deploy-debian.sh restart
```

## 安全建议

1. **更改默认端口**：修改 `NETEASE_API_PORT` 避免使用默认端口
2. **配置 SSL**：生产环境建议使用 HTTPS
3. **防火墙规则**：仅开放必要的端口
4. **定期更新**：保持系统和依赖包的更新
5. **监控日志**：定期检查访问日志和错误日志

## 技术支持

如遇到问题，请检查：

1. 系统要求：Debian 10+ 或 Ubuntu 18.04+
2. 硬件要求：至少 1GB RAM，2GB 磁盘空间
3. 网络要求：确保服务器可以访问外网（下载依赖）

更多信息请参考项目文档或提交 Issue。
