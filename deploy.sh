#!/bin/bash

# GPT-Load 简化版一键部署脚本

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "🚀 GPT-Load 简化版一键部署脚本"
    echo "================================"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  deploy      部署主节点 (默认)"
    echo "  stop        停止服务"
    echo "  restart     重启服务"
    echo "  status      查看状态"
    echo "  logs        查看日志"
    echo "  cleanup     清理环境"
    echo "  help        显示帮助"
    echo ""
    echo "示例:"
    echo "  $0              # 部署主节点"
    echo "  $0 logs         # 查看日志"
    echo "  $0 stop         # 停止服务"
    echo ""
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未启动，请启动 Docker"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 创建目录
create_directories() {
    log_info "创建必要目录..."
    
    mkdir -p data logs
    chmod -R 755 data logs
    
    log_success "目录创建完成"
}

# 生成配置
generate_config() {
    log_info "生成配置文件..."
    
    # 生成主节点配置
    if [ ! -f .env.master ]; then
        # 生成随机密钥
        AUTH_KEY=$(openssl rand -hex 32)
        
        cat > .env.master << EOF
# 简化版主节点环境配置
HOST=0.0.0.0
PORT=3001
IS_SLAVE=false
NODE_ROLE=master

# 认证配置
AUTH_KEY=$AUTH_KEY

# 数据库配置
DATABASE_DSN=/app/data/gpt-load.db

# 日志配置
LOG_LEVEL=info
LOG_FORMAT=text
LOG_ENABLE_FILE=true
LOG_FILE_PATH=/app/logs/app.log

# CORS 配置
ENABLE_CORS=true
ALLOWED_ORIGINS=*
ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS
ALLOWED_HEADERS=*
ALLOW_CREDENTIALS=false

# 性能配置
MAX_CONCURRENT_REQUESTS=100

# 服务器超时配置
SERVER_READ_TIMEOUT=60
SERVER_WRITE_TIMEOUT=600
SERVER_IDLE_TIMEOUT=120
SERVER_GRACEFUL_SHUTDOWN_TIMEOUT=10

# 系统配置
REQUEST_LOG_RETENTION_DAYS=7
REQUEST_LOG_WRITE_INTERVAL_MINUTES=1
REQUEST_TIMEOUT=600
CONNECT_TIMEOUT=15
RESPONSE_HEADER_TIMEOUT=600
MAX_IDLE_CONNS=100
MAX_IDLE_CONNS_PER_HOST=50
MAX_RETRIES=3
BLACKLIST_THRESHOLD=3
KEY_VALIDATION_INTERVAL_MINUTES=60
KEY_VALIDATION_CONCURRENCY=10
KEY_VALIDATION_TIMEOUT_SECONDS=20
EOF
        
        log_success "主节点配置已生成"
    else
        log_info "主节点配置已存在"
    fi
}

# 构建镜像
build_image() {
    log_info "构建 Docker 镜像..."
    
    # 检查是否有现有的简化版 Dockerfile
    if [ ! -f Dockerfile.simple ]; then
        log_info "创建简化版 Dockerfile..."
        cat > Dockerfile.simple << 'EOF'
# 简化版 Dockerfile
FROM golang:1.23-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装构建依赖
RUN apk add --no-cache git

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gpt-load main.go

# 最终运行阶段
FROM alpine:latest

# 安装必要的包
RUN apk --no-cache add ca-certificates tzdata wget curl

# 创建应用用户
RUN addgroup -g 1000 -S appuser && \
    adduser -u 1000 -S appuser -G appuser

# 设置工作目录
WORKDIR /app

# 创建必要的目录
RUN mkdir -p /app/data /app/logs && \
    chown -R appuser:appuser /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/gpt-load ./
COPY --chown=appuser:appuser web/dist ./web/dist

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 3001

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget -q --spider -T 10 -O /dev/null http://localhost:3001/health || exit 1

# 启动应用
CMD ["./gpt-load"]
EOF
    fi
    
    # 构建镜像
    docker build -f Dockerfile.simple -t gpt-load:latest .
    
    log_success "Docker 镜像构建完成"
}

# 启动服务
start_service() {
    log_info "启动 GPT-Load 服务..."
    
    # 启动服务
    docker-compose -f docker-compose.simple.yml up -d
    
    log_info "等待服务启动..."
    sleep 15
    
    log_success "服务启动完成"
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查主节点
    if curl -f -s http://localhost:3001/health > /dev/null 2>&1; then
        log_success "主节点服务正常"
    else
        log_error "主节点服务异常"
        return 1
    fi
    
    log_success "健康检查通过"
}

# 显示状态
show_status() {
    log_info "GPT-Load 服务状态"
    echo "================================"
    
    # 容器状态
    echo "📊 容器状态:"
    docker-compose -f docker-compose.simple.yml ps
    echo ""
    
    # 访问地址
    echo "🌐 访问地址:"
    echo "  - 主节点: http://localhost:3001"
    echo ""
    
    # 服务状态
    echo "🔍 服务状态:"
    if curl -f -s http://localhost:3001/health > /dev/null 2>&1; then
        echo "  ✅ 主节点: 健康"
    else
        echo "  ❌ 主节点: 异常"
    fi
    echo ""
    
    # 管理命令
    echo "🔧 管理命令:"
    echo "  - 查看日志: $0 logs"
    echo "  - 停止服务: $0 stop"
    echo "  - 重启服务: $0 restart"
    echo "  - 清理环境: $0 cleanup"
    echo ""
    
    # 子节点加入
    echo "🚀 子节点加入:"
    if [ -f .env.master ]; then
        source .env.master
        echo "  1. 分发镜像: docker save gpt-load:latest | docker load"
        echo "  2. 加入集群: ./join-cluster.sh <主节点IP> [节点名称]"
        echo "  3. 示例: ./join-cluster.sh 192.168.1.100 node-1"
        echo ""
    fi
}

# 主函数
main() {
    case "${1:-deploy}" in
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        "stop")
            log_info "停止 GPT-Load 服务..."
            docker-compose -f docker-compose.simple.yml down
            log_success "服务已停止"
            exit 0
            ;;
        "restart")
            log_info "重启 GPT-Load 服务..."
            docker-compose -f docker-compose.simple.yml restart
            sleep 10
            health_check
            log_success "服务重启完成"
            exit 0
            ;;
        "status")
            show_status
            exit 0
            ;;
        "logs")
            log_info "查看服务日志..."
            docker-compose -f docker-compose.simple.yml logs -f "${2:-}"
            exit 0
            ;;
        "cleanup")
            log_warning "这将删除所有容器、镜像和数据！"
            read -p "确认继续? (y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                log_info "清理环境..."
                docker-compose -f docker-compose.simple.yml down -v --remove-orphans 2>/dev/null || true
                docker rmi gpt-load:latest 2>/dev/null || true
                docker image prune -f 2>/dev/null || true
                rm -rf data logs 2>/dev/null || true
                log_success "环境清理完成"
            else
                log_info "操作已取消"
            fi
            exit 0
            ;;
        "deploy"|*)
            # 执行部署
            echo "🚀 GPT-Load 简化版一键部署"
            echo "================================"
            echo ""
            
            check_dependencies
            create_directories
            generate_config
            build_image
            start_service
            health_check
            show_status
            
            echo "🎉 GPT-Load 主节点部署完成！"
            echo ""
            echo "📖 下一步:"
            echo "  1. 访问 http://localhost:3001"
            echo "  2. 在其他服务器上运行: ./join-cluster.sh <主节点IP>"
            echo "  3. 查看帮助: $0 help"
            echo ""
            ;;
    esac
}

# 执行主函数
main "$@"