# GPT-Load 简化版部署指南

## 🎯 概述

GPT-Load 简化版提供了一个极简的集群部署方案，类似哪吒的架构设计：

- **一键部署**: 主节点一键部署，无需复杂配置
- **无依赖**: 不需要 Nginx、Redis 等额外组件
- **自动加入**: 子节点一行命令加入集群
- **直接访问**: 直接访问主节点，简化网络架构

## 🏗️ 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    GPT-Load 主节点                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Web UI    │  │   API服务   │  │  数据管理    │        │
│  │  (Port 3001)│  │  (Port 3001)│  │  (SQLite)   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    子节点 (可选)                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  节点-1     │  │  节点-2     │  │  节点-N     │        │
│  │ (Port 3001) │  │ (Port 3001) │  │ (Port 3001) │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 1. 部署主节点

```bash
# 克隆项目
git clone <repository-url>
cd gpt-load

# 一键部署
./deploy.sh
```

### 2. 子节点加入集群（傻瓜式）

**部署完成后，主节点会自动显示子节点加入命令，只需复制粘贴执行：**

```bash
# 在子节点服务器上复制这个命令并执行
curl -sSL https://raw.githubusercontent.com/solider245/gpt-load/main/join-cluster.sh | bash -s -- <主节点IP> <节点名称>
```

**示例：**
```bash
# 子节点服务器上执行
curl -sSL https://raw.githubusercontent.com/solider245/gpt-load/main/join-cluster.sh | bash -s -- 192.168.1.100 node-1
```

### 3. 手动生成加入命令

```bash
# 在主节点上运行
./generate-join-command.sh

# 或者指定参数
./generate-join-command.sh --master-ip 192.168.1.100 --node-name node-1
```

### 4. 传统加入方式

```bash
# 如果已有项目代码
./join-cluster.sh <主节点IP> [节点名称]

# 示例
./join-cluster.sh 192.168.1.100
./join-cluster.sh 192.168.1.100 node-1
```

## 📋 部署文件

### 核心文件
- `deploy.sh` - 主节点一键部署脚本
- `join-cluster.sh` - 子节点加入集群脚本
- `generate-join-command.sh` - 子节点加入命令生成器
- `docker-compose.simple.yml` - 简化版 Docker Compose 配置
- `Dockerfile.simple` - 简化版 Docker 镜像
- `.env.master` - 主节点环境配置

### 配置特点
- **零配置**: 开箱即用，无需手动编辑配置文件
- **自动生成**: 配置文件自动生成，包含随机密钥
- **傻瓜式加入**: 一行命令加入集群，无需复杂配置
- **环境变量**: 支持环境变量配置

## 📖 详细使用说明

### 主节点部署

#### 自动部署
```bash
# 完全自动部署
./deploy.sh

# 或者指定命令
./deploy.sh deploy
```

#### 手动部署
```bash
# 1. 检查依赖
./deploy.sh help

# 2. 创建目录
mkdir -p data logs

# 3. 生成配置
./deploy.sh 会自动生成配置

# 4. 构建镜像
./deploy.sh 会自动构建镜像

# 5. 启动服务
./deploy.sh 会自动启动服务
```

#### 管理命令
```bash
# 查看状态
./deploy.sh status

# 查看日志
./deploy.sh logs

# 重启服务
./deploy.sh restart

# 停止服务
./deploy.sh stop

# 清理环境
./deploy.sh cleanup

# 显示帮助
./deploy.sh help
```

### 子节点加入（傻瓜式）

#### 自动生成加入命令
主节点部署完成后，会自动显示子节点加入命令：

```bash
🎉 生成子节点加入命令...
================================

🚀 子节点加入命令:
================================

curl -sSL https://raw.githubusercontent.com/solider245/gpt-load/main/join-cluster.sh | bash -s -- 192.168.1.100 node-abc12345

💡 使用方法:
  1. 在子节点服务器上复制上面的命令
  2. 粘贴到终端并执行
  3. 等待自动安装和配置完成

📋 节点信息:
  - 主节点IP: 192.168.1.100
  - 节点名称: node-abc12345
  - 端口: 3001
```

#### 手动生成加入命令
```bash
# 在主节点上运行
./generate-join-command.sh

# 指定主节点IP
./generate-join-command.sh --master-ip 192.168.1.100

# 指定节点名称
./generate-join-command.sh --node-name node-1

# 查看帮助
./generate-join-command.sh --help
```

#### 子节点加入流程
1. **复制命令**: 从主节点复制生成的加入命令
2. **粘贴执行**: 在子节点服务器上粘贴命令并执行
3. **自动安装**: 子节点会自动下载、安装和配置
4. **完成加入**: 自动加入集群并启动服务

#### 验证加入成功
```bash
# 在子节点上检查服务状态
docker ps | grep gpt-load

# 访问子节点Web界面
curl http://localhost:3001/health

# 查看日志
docker logs gpt-load-slave
```

### 子节点加入（传统方式）

#### 基本用法
```bash
# 使用默认节点名称
./join-cluster.sh 192.168.1.100

# 指定节点名称
./join-cluster.sh 192.168.1.100 node-1

# 查看帮助
./join-cluster.sh
```

#### 子节点管理
```bash
# 查看子节点状态
curl http://localhost:3001/health

# 查看子节点日志
docker logs -f gpt-load-slave

# 停止子节点
docker stop gpt-load-slave

# 重启子节点
docker restart gpt-load-slave

# 删除子节点
docker rm -f gpt-load-slave
```

## 🔧 配置说明

### 主节点配置

#### 环境变量
```bash
# 基础配置
HOST=0.0.0.0
PORT=3001
IS_SLAVE=false
NODE_ROLE=master

# 认证配置
AUTH_KEY=your-random-auth-key

# 数据库配置
DATABASE_DSN=/app/data/gpt-load.db

# 日志配置
LOG_LEVEL=info
LOG_ENABLE_FILE=true
LOG_FILE_PATH=/app/logs/app.log

# 性能配置
MAX_CONCURRENT_REQUESTS=100
```

#### 配置文件
- `.env.master` - 主节点环境配置
- 自动生成，包含随机密钥
- 支持手动修改

### 子节点配置

#### 自动配置
子节点启动时自动配置：
- 从主节点获取认证信息
- 自动设置数据库路径
- 自动配置日志路径

#### 环境变量
```bash
# 节点角色
IS_SLAVE=true
NODE_ROLE=slave

# 主节点信息
MASTER_HOST=主节点IP
MASTER_PORT=3001

# 认证信息
AUTH_KEY=从主节点获取

# 数据库配置
DATABASE_DSN=/app/data/gpt-load-slave.db
```

## 🌐 访问地址

### 主节点
- **Web UI**: http://localhost:3001
- **API**: http://localhost:3001/api
- **健康检查**: http://localhost:3001/health

### 子节点
- **Web UI**: http://节点IP:3001
- **API**: http://节点IP:3001/api
- **健康检查**: http://节点IP:3001/health

## 🔍 监控和日志

### 主节点监控
```bash
# 查看服务状态
./deploy.sh status

# 查看实时日志
./deploy.sh logs

# 查看容器状态
docker-compose -f docker-compose.simple.yml ps

# 健康检查
curl http://localhost:3001/health
```

### 子节点监控
```bash
# 查看子节点日志
docker logs -f gpt-load-slave

# 检查子节点状态
curl http://localhost:3001/health

# 查看容器资源使用
docker stats gpt-load-slave
```

## 🚨 故障处理

### 常见问题

#### 1. 主节点启动失败
```bash
# 检查 Docker 状态
docker info

# 查看启动日志
./deploy.sh logs

# 检查端口占用
netstat -tlnp | grep 3001

# 重新部署
./deploy.sh cleanup
./deploy.sh deploy
```

#### 2. 子节点加入失败
```bash
# 检查网络连通性
ping <主节点IP>
telnet <主节点IP> 3001

# 检查主节点状态
curl http://<主节点IP>:3001/health

# 查看子节点日志
docker logs gpt-load-slave

# 重新加入
docker rm -f gpt-load-slave
./join-cluster.sh <主节点IP> <节点名称>
```

#### 3. 配置问题
```bash
# 重新生成配置
rm .env.master
./deploy.sh deploy

# 检查环境变量
docker exec gpt-load-master env | grep -E "(AUTH_KEY|DATABASE_DSN)"
```

### 数据备份和恢复

#### 备份数据
```bash
# 备份数据库
docker exec gpt-load-master tar -czf /backup/data.tar.gz -C /app/data .

# 备份配置
cp .env.master /backup/

# 备份日志
cp -r logs /backup/
```

#### 恢复数据
```bash
# 恢复数据库
docker exec gpt-load-master tar -xzf /backup/data.tar.gz -C /app/data

# 恢复配置
cp /backup/.env.master .

# 重启服务
./deploy.sh restart
```

## 🎯 最佳实践

### 生产环境配置

#### 1. 安全配置
```bash
# 使用强密码
AUTH_KEY=$(openssl rand -hex 64)

# 配置防火墙
ufw allow 3001
ufw deny 22

# 限制访问
sed -i 's/ALLOWED_ORIGINS=\*/ALLOWED_ORIGINS=https:\/\/yourdomain.com/' .env.master
```

#### 2. 性能优化
```bash
# 调整并发数
echo "MAX_CONCURRENT_REQUESTS=500" >> .env.master

# 优化日志级别
echo "LOG_LEVEL=warn" >> .env.master

# 调整超时时间
echo "REQUEST_TIMEOUT=300" >> .env.master
```

#### 3. 监控配置
```bash
# 设置定期健康检查
*/5 * * * * /path/to/deploy.sh status

# 配置日志轮转
logrotate -f /etc/logrotate.d/gpt-load

# 设置告警
# 配置监控告警规则
```

### 多节点部署

#### 主节点 (服务器1)
```bash
./deploy.sh
```

#### 子节点1 (服务器2)
```bash
./join-cluster.sh 192.168.1.100 node-1
```

#### 子节点2 (服务器3)
```bash
./join-cluster.sh 192.168.1.100 node-2
```

### 扩展性考虑

#### 水平扩展
- 支持无限子节点
- 每个子节点独立运行
- 负载均衡可通过外部 DNS 或 LB 实现

#### 功能扩展
- 支持插件系统
- 自定义中间件
- 多种存储后端

## 📈 性能优化

### 系统优化
```bash
# 增加 Docker 资源限制
docker update --memory="4g" --cpus="2" gpt-load-master

# 优化文件系统
mount -o remount,rw /app/data

# 调整内核参数
echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf
```

### 应用优化
```bash
# 调整并发数
MAX_CONCURRENT_REQUESTS=1000

# 优化连接池
MAX_IDLE_CONNS=200
MAX_IDLE_CONNS_PER_HOST=100

# 调整超时
REQUEST_TIMEOUT=120
CONNECT_TIMEOUT=30
```

## 🔐 安全建议

### 网络安全
```bash
# 配置防火墙
ufw allow 3001
ufw deny 22

# 使用 SSL/TLS
# 配置反向代理 with SSL

# 限制访问IP
# 使用白名单机制
```

### 配置安全
```bash
# 定期更换密钥
AUTH_KEY=$(openssl rand -hex 64)

# 保护配置文件
chmod 600 .env.master

# 使用环境变量注入敏感信息
```

### 监控安全
```bash
# 设置访问日志
LOG_LEVEL=info

# 监控异常访问
# 配置入侵检测

# 定期安全审计
```

## 🎉 总结

GPT-Load 简化版提供了：

- ✅ **极简部署**: 一键部署主节点
- ✅ **零配置**: 开箱即用，无需手动配置
- ✅ **自动加入**: 子节点一行命令加入集群
- ✅ **无依赖**: 不需要 Nginx、Redis 等组件
- ✅ **易于扩展**: 支持无限子节点
- ✅ **直接访问**: 简化网络架构

这个方案非常适合快速部署和测试，同时保持了生产环境的可用性。通过简单的脚本命令，您可以轻松搭建 GPT-Load 集群环境。