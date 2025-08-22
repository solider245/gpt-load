#!/bin/bash

# GPT-Load 子节点加入集群脚本 - 极简版

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
if [ $# -lt 1 ]; then
    echo "用法: $0 <主节点IP> [节点名称]"
    echo ""
    echo "示例:"
    echo "  $0 192.168.1.100                    # 使用默认名称"
    echo "  $0 192.168.1.100 node-1            # 指定节点名称"
    echo ""
    echo "说明:"
    echo "  - 主节点IP: GPT-Load 主节点的IP地址"
    echo "  - 节点名称: 可选，默认为当前主机名"
    echo ""
    exit 1
fi

MASTER_IP="$1"
NODE_NAME="${2:-$(hostname)}"

log_info "🚀 GPT-Load 子节点加入集群"
log_info "================================"
log_info "主节点地址: $MASTER_IP:3001"
log_info "节点名称: $NODE_NAME"
log_info ""

# 检查依赖
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    log_error "curl 未安装，请先安装 curl"
    exit 1
fi

# 检查主节点连通性
log_info "检查主节点连通性..."
if ! curl -f -s "http://${MASTER_IP}:3001/health" > /dev/null 2>&1; then
    log_error "无法连接到主节点 ${MASTER_IP}:3001"
    log_error "请检查:"
    echo "  1. 主节点是否正在运行"
    echo "  2. 网络连通性"
    echo "  3. 防火墙设置"
    exit 1
fi
log_success "主节点连接正常"

# 获取主节点认证信息
log_info "获取主节点配置..."
MASTER_AUTH_KEY=$(curl -s "http://${MASTER_IP}:3001/api/config/auth" 2>/dev/null | jq -r '.auth.key // empty' 2>/dev/null || true)

if [ -z "$MASTER_AUTH_KEY" ]; then
    log_error "无法获取主节点认证信息"
    log_error "请检查主节点配置和网络连接"
    exit 1
fi

log_success "获取到主节点认证信息"

# 停止现有容器
log_info "停止现有容器..."
docker stop gpt-load-slave 2>/dev/null || true
docker rm gpt-load-slave 2>/dev/null || true

# 创建数据目录
log_info "创建数据目录..."
mkdir -p /tmp/gpt-load-slave/data /tmp/gpt-load-slave/logs

# 启动子节点容器
log_info "启动子节点容器..."
docker run -d \
    --name gpt-load-slave \
    --restart always \
    -p 3001:3001 \
    -e HOST=0.0.0.0 \
    -e PORT=3001 \
    -e IS_SLAVE=true \
    -e NODE_ROLE=slave \
    -e AUTH_KEY="$MASTER_AUTH_KEY" \
    -e DATABASE_DSN=/app/data/gpt-load-slave.db \
    -e LOG_LEVEL=info \
    -e LOG_FILE_PATH=/app/logs/app.log \
    -e NODE_NAME="$NODE_NAME" \
    -e MASTER_HOST="$MASTER_IP" \
    -e MASTER_PORT=3001 \
    -v /tmp/gpt-load-slave/data:/app/data \
    -v /tmp/gpt-load-slave/logs:/app/logs \
    gpt-load:latest

log_success "子节点容器启动完成"

# 等待子节点启动
log_info "等待子节点启动..."
sleep 10

# 检查子节点状态
log_info "检查子节点状态..."
if curl -f -s "http://localhost:3001/health" > /dev/null 2>&1; then
    log_success "子节点启动成功"
else
    log_error "子节点启动失败，请检查日志"
    docker logs gpt-load-slave
    exit 1
fi

# 显示节点信息
echo ""
log_success "🎉 子节点加入集群成功！"
echo ""
echo "📊 节点信息:"
echo "  - 节点名称: $NODE_NAME"
echo "  - 主节点: $MASTER_IP:3001"
echo "  - 本地地址: http://localhost:3001"
echo "  - 容器名称: gpt-load-slave"
echo ""
echo "🔧 管理命令:"
echo "  - 查看日志: docker logs -f gpt-load-slave"
echo "  - 停止节点: docker stop gpt-load-slave"
echo "  - 重启节点: docker restart gpt-load-slave"
echo "  - 删除节点: docker rm -f gpt-load-slave"
echo ""
echo "🔗 验证节点状态:"
echo "  - 本地检查: curl http://localhost:3001/health"
echo "  - 主节点检查: curl http://${MASTER_IP}:3001/health"
echo ""
echo "⚠️  注意事项:"
echo "  - 请确保主节点正常运行"
echo "  - 防火墙需要开放 3001 端口"
echo "  - 建议定期备份数据"
echo ""