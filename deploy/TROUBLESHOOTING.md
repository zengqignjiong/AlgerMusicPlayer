# 部署故障排除指南

## npm install 被 Killed 问题

### 🔍 问题原因
- **内存不足**: 服务器内存小于 1GB
- **交换空间不足**: 没有配置交换文件
- **Node.js 内存限制**: 默认内存限制过低

### 🛠️ 解决方案

#### 方案 1: 使用低内存部署脚本
```bash
cd /opt/AlgerMusicPlayer
chmod +x deploy/low-memory-deploy.sh
sudo ./deploy/low-memory-deploy.sh
```

#### 方案 2: 手动创建交换文件
```bash
# 创建 2GB 交换文件
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 验证交换文件
free -h
```

#### 方案 3: 手动安装依赖
```bash
# 清理旧文件
rm -rf node_modules package-lock.json
npm cache clean --force

# 使用低内存参数安装
export NODE_OPTIONS="--max_old_space_size=512"
npm install --no-optional --no-audit --no-fund --legacy-peer-deps

# 构建项目
export NODE_OPTIONS="--max_old_space_size=1024"
npm run build
```

#### 方案 4: 分批安装依赖
```bash
# 先安装核心依赖
npm install --production --no-optional

# 再安装开发依赖
npm install --only=dev --no-optional

# 最后构建
npm run build
```

### 📊 检查系统资源

```bash
# 检查内存使用
free -h

# 检查磁盘空间
df -h

# 检查交换空间
swapon --show

# 监控资源使用
top
```

### 🔧 优化建议

1. **服务器配置**:
   - 最低配置: 1GB RAM + 20GB 磁盘
   - 推荐配置: 2GB RAM + 40GB 磁盘

2. **系统优化**:
   ```bash
   # 关闭不必要的服务
   sudo systemctl stop apache2 2>/dev/null || true
   sudo systemctl stop mysql 2>/dev/null || true
   
   # 清理系统缓存
   sudo apt-get clean
   sudo apt-get autoremove
   ```

3. **Node.js 优化**:
   ```bash
   # 在 ~/.bashrc 中添加
   export NODE_OPTIONS="--max_old_space_size=1024"
   export NPM_CONFIG_PROGRESS=false
   ```

### 🐳 Docker 替代方案

如果内存问题无法解决，可以使用预构建镜像:

```bash
# 拉取预构建的前端
docker run --rm -v $(pwd):/workspace node:18-alpine sh -c "
  cd /workspace && 
  npm ci --production --no-optional && 
  npm run build
"
```

### 🆘 紧急修复

如果所有方案都失败:

1. **增加服务器内存** (最直接的解决方案)
2. **使用本地构建** + 上传产物:
   ```bash
   # 在本地构建
   npm run build
   
   # 上传构建产物到服务器
   scp -r out/ user@server:/opt/AlgerMusicPlayer/
   ```

3. **使用 GitHub Actions** 自动构建并部署
