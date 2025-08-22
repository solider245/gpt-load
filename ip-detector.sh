#!/bin/bash

# GPT-Load IP地址检测和修正工具

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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

log_tip() {
    echo -e "${PURPLE}[TIP]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "🌐 GPT-Load IP地址检测和修正工具"
    echo "================================"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --auto               自动检测并选择最佳IP"
    echo "  --list               列出所有检测到的IP地址"
    echo "  --public             优先显示公网IP"
    echo "  --private            优先显示内网IP"
    echo "  --validate <IP>      验证IP地址是否有效"
    echo "  --fix                交互式修正IP地址"
    echo "  --help, -h           显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 --auto             # 自动检测最佳IP"
    echo "  $0 --list            # 列出所有IP"
    echo "  $0 --fix             # 交互式修正IP"
    echo ""
}

# 验证IP地址格式
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a ip_parts <<< "$ip"
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# 检查IP是否为内网IP
is_private_ip() {
    local ip="$1"
    if [[ $ip =~ ^10\. ]] || [[ $ip =~ ^192\.168\. ]] || [[ $ip =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]; then
        return 0
    fi
    return 1
}

# 检查IP是否为公网IP
is_public_ip() {
    local ip="$1"
    if validate_ip "$ip" && ! is_private_ip "$ip" && [[ $ip != "127.0.0.1" ]]; then
        return 0
    fi
    return 1
}

# 检测所有IP地址
detect_all_ips() {
    log_info "检测所有可用的IP地址..."
    echo ""
    
    local ips=()
    local descriptions=()
    
    # 1. 检测内网IP
    if command -v ip &> /dev/null; then
        local route_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
        if validate_ip "$route_ip"; then
            ips+=("$route_ip")
            descriptions+=("内网IP (默认路由)")
        fi
    fi
    
    # 2. 检测所有网络接口IP
    if command -v ifconfig &> /dev/null; then
        local interface_ips=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
        while read -r ip; do
            if validate_ip "$ip" && [[ ! " ${ips[@]} " =~ " ${ip} " ]]; then
                if is_private_ip "$ip"; then
                    ips+=("$ip")
                    descriptions+=("内网IP (网络接口)")
                else
                    ips+=("$ip")
                    descriptions+=("公网IP (网络接口)")
                fi
            fi
        done <<< "$interface_ips"
    fi
    
    # 3. 检测hostname IP
    if command -v hostname &> /dev/null; then
        local hostname_ip=""
        if hostname -I &> /dev/null; then
            hostname_ip=$(hostname -I | awk '{print $1}')
        else
            hostname_ip=$(hostname | head -1)
        fi
        if validate_ip "$hostname_ip" && [[ ! " ${ips[@]} " =~ " ${hostname_ip} " ]]; then
            if is_private_ip "$hostname_ip"; then
                ips+=("$hostname_ip")
                descriptions+=("内网IP (hostname)")
            else
                ips+=("$hostname_ip")
                descriptions+=("公网IP (hostname)")
            fi
        fi
    fi
    
    # 4. 检测外网IP
    if command -v curl &> /dev/null; then
        local public_ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null || echo "")
        if validate_ip "$public_ip" && [[ ! " ${ips[@]} " =~ " ${public_ip} " ]]; then
            ips+=("$public_ip")
            descriptions+=("公网IP (外网检测)")
        fi
    fi
    
    # 显示检测结果
    if [ ${#ips[@]} -eq 0 ]; then
        log_error "未检测到任何有效的IP地址"
        return 1
    fi
    
    echo "📋 检测到的IP地址列表："
    echo "================================"
    for i in "${!ips[@]}"; do
        local ip="${ips[$i]}"
        local desc="${descriptions[$i]}"
        local type=""
        
        if is_private_ip "$ip"; then
            type="${YELLOW}[内网]${NC}"
        else
            type="${GREEN}[公网]${NC}"
        fi
        
        echo "$((i+1)). $ip $type - $desc"
    done
    echo ""
    
    # 返回数组
    printf '%s\n' "${ips[@]}"
}

# 自动选择最佳IP
auto_select_best_ip() {
    log_info "自动选择最佳IP地址..."
    
    local ips=()
    while IFS= read -r line; do
        ips+=("$line")
    done < <(detect_all_ips)
    
    if [ ${#ips[@]} -eq 0 ]; then
        echo ""
        return 1
    fi
    
    # 选择策略：优先内网IP，其次公网IP
    local best_ip=""
    for ip in "${ips[@]}"; do
        if is_private_ip "$ip"; then
            best_ip="$ip"
            break
        fi
    done
    
    # 如果没有内网IP，选择第一个公网IP
    if [ -z "$best_ip" ]; then
        best_ip="${ips[0]}"
    fi
    
    echo ""
    echo "🎯 自动选择的IP地址：${CYAN}$best_ip${NC}"
    
    if is_private_ip "$best_ip"; then
        echo "💡 类型：内网IP - 适合局域网内部部署"
    else
        echo "🌐 类型：公网IP - 适合互联网部署"
    fi
    echo ""
    
    echo "$best_ip"
}

# 交互式修正IP
interactive_fix_ip() {
    echo ""
    echo "🔧 IP地址交互式修正工具"
    echo "================================"
    echo ""
    
    # 首先显示当前检测到的IP
    log_info "当前检测到的IP地址："
    detect_all_ips > /dev/null
    
    echo ""
    echo "请选择操作："
    echo "1. 使用检测到的IP地址"
    echo "2. 手动输入IP地址"
    echo "3. 重新检测IP地址"
    echo "4. 取消"
    echo ""
    
    read -p "请输入选择 (1-4): " choice
    
    case $choice in
        1)
            echo ""
            read -p "请输入要使用的IP地址编号: " ip_number
            local ips=()
            while IFS= read -r line; do
                ips+=("$line")
            done < <(detect_all_ips)
            
            if [[ $ip_number =~ ^[0-9]+$ ]] && [ $ip_number -ge 1 ] && [ $ip_number -le ${#ips[@]} ]; then
                local selected_ip="${ips[$((ip_number-1))]}"
                echo ""
                log_success "已选择IP地址：$selected_ip"
                echo "$selected_ip"
            else
                log_error "无效的IP地址编号"
                exit 1
            fi
            ;;
        2)
            echo ""
            read -p "请输入IP地址: " manual_ip
            if validate_ip "$manual_ip"; then
                echo ""
                log_success "已设置IP地址：$manual_ip"
                if is_private_ip "$manual_ip"; then
                    echo "💡 类型：内网IP - 适合局域网内部部署"
                else
                    echo "🌐 类型：公网IP - 适合互联网部署"
                fi
                echo ""
                echo "$manual_ip"
            else
                log_error "无效的IP地址格式"
                exit 1
            fi
            ;;
        3)
            exec "$0" --fix
            ;;
        4)
            echo ""
            log_info "操作已取消"
            exit 0
            ;;
        *)
            log_error "无效的选择"
            exit 1
            ;;
    esac
}

# 显示常见错误和解决方案
show_common_issues() {
    echo ""
    echo "⚠️  常见问题和解决方案"
    echo "================================"
    echo ""
    
    echo "🔍 问题1：子节点无法连接到主节点"
    echo "   原因：IP地址不正确或防火墙阻止"
    echo "   解决："
    echo "   - 检查主节点IP地址是否正确"
    echo "   - 确保子节点可以ping通主节点IP"
    echo "   - 检查防火墙设置，开放3001端口"
    echo ""
    
    echo "🔍 问题2：检测到错误的IP地址"
    echo "   原因：系统有多个网络接口"
    echo "   解决："
    echo "   - 使用 $0 --list 查看所有IP"
    echo "   - 使用 $0 --fix 手动选择正确的IP"
    echo "   - 手动指定IP：./generate-join-command.sh --master-ip <正确IP>"
    echo ""
    
    echo "🔍 问题3：内网IP vs 公网IP选择"
    echo "   内网IP (192.168.x.x, 10.x.x.x, 172.16-31.x.x)："
    echo "   - 适用于同一局域网内的设备"
    echo "   - 子节点必须在同一网络中"
    echo ""
    echo "   公网IP："
    echo "   - 适用于互联网访问"
    echo "   - 需要配置端口转发和防火墙"
    echo "   - 子节点可以从任何地方访问"
    echo ""
    
    echo "🔍 问题4：Docker网络问题"
    echo "   解决："
    echo "   - 确保Docker服务正在运行"
    echo "   - 检查端口3001是否被占用"
    echo "   - 使用 docker ps 检查容器状态"
    echo ""
    
    echo "💡 提示：使用 $0 --auto 自动选择最佳IP地址"
    echo ""
}

# 主函数
main() {
    case "${1:---auto}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --list)
            detect_all_ips
            ;;
        --auto)
            auto_select_best_ip
            ;;
        --public)
            log_info "优先显示公网IP..."
            detect_all_ips | grep -v "127.0.0.1" | while read ip; do
                if is_public_ip "$ip"; then
                    echo "🌐 公网IP: $ip"
                fi
            done
            ;;
        --private)
            log_info "优先显示内网IP..."
            detect_all_ips | while read ip; do
                if is_private_ip "$ip"; then
                    echo "🏠 内网IP: $ip"
                fi
            done
            ;;
        --validate)
            if validate_ip "$2"; then
                if is_private_ip "$2"; then
                    echo "✅ $2 是有效的内网IP地址"
                elif is_public_ip "$2"; then
                    echo "✅ $2 是有效的公网IP地址"
                else
                    echo "✅ $2 是有效的IP地址"
                fi
            else
                echo "❌ $2 不是有效的IP地址格式"
                exit 1
            fi
            ;;
        --fix)
            interactive_fix_ip
            ;;
        --issues)
            show_common_issues
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"