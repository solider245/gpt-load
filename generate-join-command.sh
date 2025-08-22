#!/bin/bash

# GPT-Load 子节点加入命令生成器

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo "🚀 GPT-Load 子节点加入命令生成器"
    echo "================================"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --master-ip <IP>      指定主节点IP (默认自动检测)"
    echo "  --node-name <NAME>    指定节点名称 (默认自动生成)"
    echo "  --port <PORT>         指定端口 (默认3001)"
    echo "  --help, -h            显示帮助"
    echo ""
    echo "示例:"
    echo "  $0                           # 自动检测配置"
    echo "  $0 --master-ip 192.168.1.100 # 指定主节点IP"
    echo "  $0 --node-name node-1       # 指定节点名称"
    echo ""
}

# 获取主节点IP
get_master_ip() {
    local master_ip="$1"
    
    if [ -z "$master_ip" ]; then
        # 智能检测IP
        master_ip=$(get_master_ip_auto)
        
        if [ "$master_ip" = "<你的主节点IP>" ]; then
            log_error "无法自动检测主节点IP，请使用 --master-ip 参数指定"
            exit 1
        fi
    fi
    
    echo "$master_ip"
}

# 智能获取主节点IP
get_master_ip_auto() {
    local master_ip=""
    
    # 1. 首先尝试获取内网IP（更适合局域网部署）
    if command -v ip &> /dev/null; then
        # 获取默认路由的IP
        master_ip=$(ip route get 1.1.1.1 | awk '{print $7}' | head -1 2>/dev/null || echo "")
    fi
    
    # 2. 如果没有获取到，尝试其他方法
    if [ -z "$master_ip" ] && command -v hostname &> /dev/null; then
        master_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
    fi
    
    # 3. 如果还是没有，尝试ifconfig
    if [ -z "$master_ip" ] && command -v ifconfig &> /dev/null; then
        master_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1 2>/dev/null || echo "")
    fi
    
    # 4. 如果还是没有，获取外网IP（用于公网部署）
    if [ -z "$master_ip" ] && command -v curl &> /dev/null; then
        master_ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
    fi
    
    # 5. 最后检查是否为有效的IP地址
    if [ -z "$master_ip" ] || [ "$master_ip" = "localhost" ] || [ "$master_ip" = "127.0.0.1" ]; then
        log_warning "无法自动检测到有效的IP地址，请手动指定"
        log_info "使用方法: ./generate-join-command.sh --master-ip <你的IP地址>"
        master_ip="<你的主节点IP>"
    fi
    
    echo "$master_ip"
}

# 生成节点名称
generate_node_name() {
    local node_name="$1"
    
    if [ -z "$node_name" ]; then
        # 生成随机节点名称
        local random_id=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
        node_name="node-${random_id}"
    fi
    
    echo "$node_name"
}

# 生成加入命令
generate_join_command() {
    local master_ip="$1"
    local node_name="$2"
    local port="$3"
    
    # 从配置文件读取AUTH_KEY
    local auth_key=""
    if [ -f .env.master ]; then
        source .env.master
        auth_key="$AUTH_KEY"
    else
        log_error "未找到 .env.master 配置文件"
        exit 1
    fi
    
    # 生成完整的加入命令
    local join_command="curl -sSL https://raw.githubusercontent.com/solider245/gpt-load/main/join-cluster.sh | bash -s -- ${master_ip} ${node_name}"
    
    echo "$join_command"
}

# 显示加入信息
show_join_info() {
    local master_ip="$1"
    local node_name="$2"
    local port="$3"
    local join_command="$4"
    
    echo ""
    echo "🎉 GPT-Load 主节点部署成功！"
    echo "================================"
    echo ""
    echo "🌐 访问信息:"
    echo "  - 主节点地址: http://${master_ip}:${port}"
    echo "  - 管理界面: http://${master_ip}:${port}"
    echo "  - API地址: http://${master_ip}:${port}/api"
    echo ""
    echo "🚀 子节点加入命令:"
    echo "================================"
    echo ""
    echo "${CYAN}${join_command}${NC}"
    echo ""
    echo "💡 使用方法:"
    echo "  1. 在子节点服务器上复制上面的命令"
    echo "  2. 粘贴到终端并执行"
    echo "  3. 等待自动安装和配置完成"
    echo ""
    echo "📋 子节点信息:"
    echo "  - 主节点IP: ${master_ip}"
    echo "  - 节点名称: ${node_name}"
    echo "  - 端口: ${port}"
    echo ""
    echo "🔧 管理命令:"
    echo "  - 查看状态: ./deploy.sh status"
    echo "  - 查看日志: ./deploy.sh logs"
    echo "  - 停止服务: ./deploy.sh stop"
    echo "  - 重启服务: ./deploy.sh restart"
    echo ""
    echo "⚠️  注意事项:"
    echo "  - 确保子节点能够访问主节点IP"
    echo "  - 确保子节点已安装Docker"
    echo "  - 建议在相同的网络环境中部署"
    echo ""
}

# 主函数
main() {
    local master_ip=""
    local node_name=""
    local port="3001"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --master-ip)
                master_ip="$2"
                shift 2
                ;;
            --node-name)
                node_name="$2"
                shift 2
                ;;
            --port)
                port="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查配置文件
    if [ ! -f .env.master ]; then
        log_error "未找到 .env.master 配置文件，请先运行 ./deploy.sh"
        exit 1
    fi
    
    # 检查服务状态
    if ! curl -f -s "http://localhost:${port}/health" > /dev/null 2>&1; then
        log_error "主节点服务未运行，请先启动服务: ./deploy.sh"
        exit 1
    fi
    
    # 获取配置
    master_ip=$(get_master_ip "$master_ip")
    node_name=$(generate_node_name "$node_name")
    
    # 生成加入命令
    join_command=$(generate_join_command "$master_ip" "$node_name" "$port")
    
    # 显示加入信息
    show_join_info "$master_ip" "$node_name" "$port" "$join_command"
    
    # 保存加入信息到文件
    cat > join-info.txt << EOF
GPT-Load 子节点加入信息
========================

主节点IP: $master_ip
节点名称: $node_name
端口: $port

加入命令:
$join_command

生成时间: $(date)
EOF
    
    log_success "加入信息已保存到 join-info.txt"
}

# 执行主函数
main "$@"