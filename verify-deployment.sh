#!/bin/bash

# GPT-Load 简化版部署验证脚本

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

# 验证文件完整性
verify_files() {
    log_info "验证部署文件完整性..."
    
    local required_files=(
        "deploy.sh"
        "join-cluster.sh"
        "docker-compose.simple.yml"
        "Dockerfile.simple"
        ".env.master"
        "README_SIMPLIFIED.md"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_success "所有部署文件存在"
    else
        log_error "缺少以下文件: ${missing_files[*]}"
        return 1
    fi
}

# 验证脚本权限
verify_permissions() {
    log_info "验证脚本执行权限..."
    
    local scripts=("deploy.sh" "join-cluster.sh")
    
    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            log_success "$script 具有执行权限"
        else
            log_error "$script 缺少执行权限"
            chmod +x "$script"
            log_success "已为 $script 添加执行权限"
        fi
    done
}

# 验证Docker环境
verify_docker() {
    log_info "验证Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        return 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未启动"
        return 1
    fi
    
    log_success "Docker 环境正常"
}

# 验证配置文件
verify_config() {
    log_info "验证配置文件..."
    
    if [ ! -f .env.master ]; then
        log_error "主节点配置文件不存在"
        return 1
    fi
    
    # 检查必要的环境变量
    source .env.master
    
    local required_vars=("HOST" "PORT" "IS_SLAVE" "NODE_ROLE" "AUTH_KEY")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
            return 1
        fi
    done
    
    log_success "配置文件验证通过"
}

# 验证Docker Compose配置
verify_docker_compose() {
    log_info "验证Docker Compose配置..."
    
    if ! docker-compose -f docker-compose.simple.yml config > /dev/null 2>&1; then
        log_error "Docker Compose 配置无效"
        return 1
    fi
    
    log_success "Docker Compose 配置有效"
}

# 验证网络连通性
verify_network() {
    log_info "验证网络连通性..."
    
    # 检查端口占用
    if netstat -tlnp 2>/dev/null | grep -q ":3001 "; then
        log_warning "端口 3001 已被占用"
    else
        log_success "端口 3001 可用"
    fi
    
    # 检查Docker网络
    if docker network ls | grep -q "gpt-load-network"; then
        log_warning "Docker 网络 gpt-load-network 已存在"
    else
        log_success "Docker 网络 gpt-load-network 可用"
    fi
}

# 验证构建依赖
verify_build_deps() {
    log_info "验证构建依赖..."
    
    if [ ! -f "go.mod" ]; then
        log_error "Go 模块文件不存在"
        return 1
    fi
    
    if [ ! -f "main.go" ]; then
        log_error "主程序文件不存在"
        return 1
    fi
    
    if [ ! -d "web/dist" ]; then
        log_warning "前端资源目录不存在，构建可能会失败"
    fi
    
    log_success "构建依赖检查通过"
}

# 运行完整验证
run_full_verification() {
    log_info "开始完整验证..."
    echo ""
    
    local failed_steps=()
    
    # 验证文件完整性
    if ! verify_files; then
        failed_steps+=("文件完整性")
    fi
    echo ""
    
    # 验证脚本权限
    if ! verify_permissions; then
        failed_steps+=("脚本权限")
    fi
    echo ""
    
    # 验证Docker环境
    if ! verify_docker; then
        failed_steps+=("Docker环境")
    fi
    echo ""
    
    # 验证配置文件
    if ! verify_config; then
        failed_steps+=("配置文件")
    fi
    echo ""
    
    # 验证Docker Compose配置
    if ! verify_docker_compose; then
        failed_steps+=("Docker Compose配置")
    fi
    echo ""
    
    # 验证网络连通性
    if ! verify_network; then
        failed_steps+=("网络连通性")
    fi
    echo ""
    
    # 验证构建依赖
    if ! verify_build_deps; then
        failed_steps+=("构建依赖")
    fi
    echo ""
    
    # 输出验证结果
    if [ ${#failed_steps[@]} -eq 0 ]; then
        log_success "🎉 所有验证步骤通过！"
        echo ""
        log_info "可以开始部署："
        echo "  ./deploy.sh"
        echo ""
        log_info "部署完成后，可以添加子节点："
        echo "  ./join-cluster.sh <主节点IP> [节点名称]"
        echo ""
    else
        log_error "❌ 验证失败，以下步骤需要修复："
        for step in "${failed_steps[@]}"; do
            echo "  - $step"
        done
        echo ""
        log_info "请修复上述问题后重新运行验证"
        return 1
    fi
}

# 显示验证信息
show_verification_info() {
    echo "🔍 GPT-Load 简化版部署验证"
    echo "================================"
    echo ""
    echo "此脚本将验证以下内容："
    echo "  ✅ 部署文件完整性"
    echo "  ✅ 脚本执行权限"
    echo "  ✅ Docker 环境配置"
    echo "  ✅ 配置文件有效性"
    echo "  ✅ Docker Compose 配置"
    echo "  ✅ 网络连通性"
    echo "  ✅ 构建依赖检查"
    echo ""
    echo "开始验证..."
    echo ""
}

# 主函数
main() {
    case "${1:-full}" in
        "help"|"-h"|"--help")
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  full     完整验证 (默认)"
            echo "  files    仅验证文件"
            echo "  docker   仅验证Docker"
            echo "  config   仅验证配置"
            echo "  network  仅验证网络"
            echo "  help     显示帮助"
            echo ""
            ;;
        "files")
            verify_files
            verify_permissions
            ;;
        "docker")
            verify_docker
            verify_docker_compose
            ;;
        "config")
            verify_config
            ;;
        "network")
            verify_network
            ;;
        "full"|*)
            show_verification_info
            run_full_verification
            ;;
    esac
}

# 执行主函数
main "$@"