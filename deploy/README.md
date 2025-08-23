# AlgerMusicPlayer 部署目录说明

## 📁 目录结构

```
deploy/
├── deploy-debian.sh         # 主要部署脚本 - Debian/Ubuntu Docker 部署
├── deploy.sh               # 部署入口脚本 - 提供部署方式选择
├── deploy-with-config.sh   # 🆕 配置化部署脚本 - 支持自定义配置
├── quick-deploy.sh         # 快速部署脚本 - 一键部署
├── low-memory-deploy.sh    # 低内存服务器专用部署脚本
├── fix-deploy.sh          # 部署问题修复脚本
├── config.env             # 🆕 部署配置文件 - 可自定义仓库地址等
├── README.md              # 本文档 - 目录说明
├── README-DEPLOY.md       # 详细部署文档和故障排除指南
├── TROUBLESHOOTING.md     # 故障排除专用指南
└── nginx/                 # Nginx 配置目录
    ├── docker-compose-nginx.yml    # Nginx Docker 编排配置
    ├── nginx.conf                  # Nginx 主配置文件
    ├── conf/
    │   └── music.conf             # 音乐应用代理配置
    ├── html/                      # 静态文件目录
    └── logs/                      # Nginx 日志目录
        ├── access.log
        └── error.log
```

## 🚀 快速使用

### 配置化部署 (🆕 推荐)

```bash
# 1. 编辑配置文件 (可选)
nano deploy/config.env

# 2. 使用配置部署
cd /opt/AlgerMusicPlayer/deploy
sudo ./deploy-with-config.sh

# 3. 查看当前配置
./deploy-with-config.sh config
```

### 完整部署
```bash
# 上传项目到服务器后
cd /opt/AlgerMusicPlayer
sudo ./deploy/deploy-debian.sh
```

### 快速部署
```bash
cd /opt/AlgerMusicPlayer/deploy
sudo ./quick-deploy.sh
```

### 选择性部署
```bash
cd /opt/AlgerMusicPlayer
sudo ./deploy/deploy.sh
# 选择部署方式：1-Docker部署 或 2-传统部署
```

## 📋 管理命令

```bash
# 查看状态
./deploy/deploy-debian.sh status

# 重启服务
./deploy/deploy-debian.sh restart

# 停止服务
./deploy/deploy-debian.sh stop
```

## 📖 详细说明

请查看 `README-DEPLOY.md` 获取详细的部署指南、配置说明和故障排除方法。
