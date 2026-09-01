#!/usr/bin/env bash
# ==============================================================================
# 黑天鹅 AI 专属一键工具箱 (HTE-AI Box)
# ==============================================================================

set +e

# Target installation directory
AIBOX_DIR="/etc/hte-ai-box"
REPO_RAW_URL="https://raw.githubusercontent.com/ithtelab/hte-ai-box/main"
CDN_URL="https://cdn.jsdelivr.net/gh/ithtelab/hte-ai-box@main"
GH_PROXY="https://ghproxy.com/https://raw.githubusercontent.com/ithtelab/hte-ai-box/main"

download_file() {
    local rel_path="$1"
    local target_file="${AIBOX_DIR}/${rel_path}"
    local ts
    ts=$(date +%s%N 2>/dev/null || date +%s)
    mkdir -p "$(dirname "$target_file")"

    if curl -fsSL -H "Accept: application/vnd.github.raw" \
        "https://api.github.com/repos/ithtelab/hte-ai-box/contents/${rel_path}?ref=main" \
        -o "$target_file" 2>/dev/null && [ -s "$target_file" ]; then
        return 0
    elif curl -fsSL -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "${REPO_RAW_URL}/${rel_path}?t=${ts}" -o "$target_file" 2>/dev/null; then
        return 0
    elif curl -fsSL -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "${CDN_URL}/${rel_path}?t=${ts}" -o "$target_file" 2>/dev/null; then
        return 0
    elif curl -fsSL -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "${GH_PROXY}/${rel_path}?t=${ts}" -o "$target_file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Bootstrap when run via curl | bash
if [ -d "$(dirname "${BASH_SOURCE[0]}")/utils" ]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    echo -e "\033[1;34m[INFO]\033[0m 正在初始化黑天鹅 AI 专属工具箱运行环境..."
    mkdir -p "${AIBOX_DIR}/utils" "${AIBOX_DIR}/modules"
    for f in "utils/colors.sh" "utils/sys_detect.sh" "utils/helper.sh" \
             "modules/ai_gateway.sh" "modules/ai_proxy.sh" "modules/ai_frontend.sh" "modules/ai_ops.sh" \
             "main.sh"; do
        download_file "$f" || true
    done
    chmod +x "${AIBOX_DIR}/main.sh"
    ln -sf "${AIBOX_DIR}/main.sh" /usr/local/bin/htei 2>/dev/null || true
    BASE_DIR="${AIBOX_DIR}"
fi

load_modules() {
    [ -f "${BASE_DIR}/utils/colors.sh" ] && . "${BASE_DIR}/utils/colors.sh"
    [ -f "${BASE_DIR}/utils/sys_detect.sh" ] && . "${BASE_DIR}/utils/sys_detect.sh"
    [ -f "${BASE_DIR}/utils/helper.sh" ] && . "${BASE_DIR}/utils/helper.sh"
    [ -f "${BASE_DIR}/modules/ai_gateway.sh" ] && . "${BASE_DIR}/modules/ai_gateway.sh"
    [ -f "${BASE_DIR}/modules/ai_proxy.sh" ] && . "${BASE_DIR}/modules/ai_proxy.sh"
    [ -f "${BASE_DIR}/modules/ai_frontend.sh" ] && . "${BASE_DIR}/modules/ai_frontend.sh"
    [ -f "${BASE_DIR}/modules/ai_ops.sh" ] && . "${BASE_DIR}/modules/ai_ops.sh"
}

load_modules

init_environment() {
    check_root
    detect_system
    install_dependencies
    if [ ! -f /usr/local/bin/htei ] && [ -f "${AIBOX_DIR}/main.sh" ]; then
        ln -sf "${AIBOX_DIR}/main.sh" /usr/local/bin/htei 2>/dev/null || true
    fi
}

install_docker_if_missing() {
    if ! command -v docker >/dev/null 2>&1; then
        info "未检测到 Docker, 正在安装..."
        curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun 2>/dev/null || curl -fsSL https://get.docker.com | bash
        systemctl enable --now docker >/dev/null 2>&1 || true
        command -v docker >/dev/null 2>&1 && success "Docker 安装成功: $(docker --version)" || error "Docker 安装失败"
    else
        success "Docker 已就绪: $(docker --version)"
    fi
}

update_toolbox() {
    echo ""
    info "正在穿透 CDN 缓存拉取最新代码与所有模块..."
    mkdir -p "${AIBOX_DIR}/utils" "${AIBOX_DIR}/modules"
    local update_files=("utils/colors.sh" "utils/sys_detect.sh" "utils/helper.sh" \
        "modules/ai_gateway.sh" "modules/ai_proxy.sh" "modules/ai_frontend.sh" "modules/ai_ops.sh")
    local fail_count=0
    for f in "${update_files[@]}"; do
        download_file "$f" || fail_count=$((fail_count + 1))
    done
    if download_file "main.sh" && [ -s "${AIBOX_DIR}/main.sh" ]; then
        :
    else
        fail_count=$((fail_count + 1))
    fi
    chmod +x "${AIBOX_DIR}/main.sh"
    ln -sf "${AIBOX_DIR}/main.sh" /usr/local/bin/htei 2>/dev/null || true
    if [ "$fail_count" -eq 0 ]; then
        success "黑天鹅 AI 工具箱已成功更新至最新版本！正在无缝热重载..."
        load_modules
        sleep 1
        exec bash "${AIBOX_DIR}/main.sh"
    else
        warn "部分文件更新可能受网络阻碍，建议检查服务器网络。"
        pause
    fi
}

main_menu() {
    while true; do
        print_banner
        echo -e " ${WHITE}系统:${NC} ${OS_NAME} ${OS_VERSION} (${CPU_ARCH}) | ${WHITE}内存:${NC} $(get_mem_info) | ${WHITE}磁盘:${NC} $(get_disk_info)"
        echo -e " ${WHITE}网络:${NC} IP $(get_ip_info) | ${WHITE}Docker:${NC} $(command -v docker >/dev/null 2>&1 && echo "$(docker --version | sed 's/Docker version //')" || echo "未安装")"
        double_separator
        echo -e " ${B_GREEN}[1]${NC} ${B_WHITE}AI 网关与订阅${NC}   ${PURPLE}(new-api, sub2api)${NC}"
        echo -e " ${B_GREEN}[2]${NC} ${B_WHITE}中转与本地推理${NC} ${PURPLE}(CLIProxyAPI cpa, Ollama)${NC}"
        echo -e " ${B_GREEN}[3]${NC} ${B_WHITE}AI 对话前端${NC}     ${PURPLE}(NextChat, LobeChat)${NC}"
        echo -e " ${B_GREEN}[4]${NC} ${B_WHITE}公网暴露与运维${NC}   ${PURPLE}(CF Tunnel, 备份, TG 告警)${NC}"
        separator
        echo -e " ${B_YELLOW}[d]${NC} 安装 Docker   ${B_YELLOW}[u]${NC} 更新脚本   ${B_RED}[0]${NC} 退出"
        double_separator
        read -r -p "请输入功能编号 [0-4 或 d/u]: " main_choice
        case "$main_choice" in
            1) menu_ai_gateway ;;
            2) menu_ai_proxy ;;
            3) menu_ai_frontend ;;
            4) menu_ai_ops ;;
            d|D) install_docker_if_missing ;;
            u|U) update_toolbox ;;
            0)
                echo ""
                echo -e "${B_GREEN}感谢使用 黑天鹅 AI 专属一键工具箱，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}输入有误，请重新输入数字 0-4 或 d/u！${NC}"
                sleep 1
                ;;
        esac
    done
}

init_environment
main_menu
