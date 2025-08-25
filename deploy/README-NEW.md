# AlgerMusicPlayer 部署指南

本目录包含了 AlgerMusicPlayer 在不同操作系统上的部署脚本。

## 支持的系统

- **Ubuntu/Debian**: 使用 `deploy-debian.sh`
- **CentOS/RHEL**: 使用 `deploy-centos.sh`
- **通用系统**: 使用 `deploy.sh`

## 快速部署

### Debian/Ubuntu 系统
```bash
chmod +x deploy-debian.sh
sudo ./deploy-debian.sh
```

### CentOS/RHEL 系统
```bash
chmod +x deploy-centos.sh
sudo ./deploy-centos.sh
```

### 其他系统
```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

## 部署内容

每个脚本都会自动：
1. 安装必要的依赖（Docker, Node.js, nginx）
2. 克隆项目代码和API服务代码
3. 构建并启动网易云音乐API服务（端口3000）
4. 构建并部署前端服务（端口80）
5. 配置nginx反向代理
6. 设置防火墙规则

## 访问地址

部署完成后可通过以下地址访问：
- **前端服务**: http://服务器IP
- **API服务**: http://服务器IP:3000

## 注意事项

- 需要root权限运行脚本
- 建议至少2GB内存（脚本会自动创建swap）
- 确保80和3000端口未被占用
- 网络需要能够访问GitHub和npm仓库

## 故障排除

如遇到问题，请检查：
1. 系统是否支持
2. 网络连接是否正常
3. 运行权限是否正确
4. 查看脚本输出的错误信息
