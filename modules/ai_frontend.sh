#!/usr/bin/env bash
# ==============================================================================
# HTE-AI Box - AI Chat Frontend Module (NextChat, LobeChat)
# ==============================================================================

get_gateway_url() {
    # Try to detect a running new-api gateway to auto-fill the frontend
    local gw_ip
    gw_ip=$(get_ip_info)
    local gw_port=3000
    if docker ps --filter name=new-api --format '{{.Ports}}' | grep -q "3000"; then
        echo "http://${gw_ip}:${gw_port}"
    else
        echo ""
    fi
}

install_nextchat() {
    print_banner
    echo -e "${B_YELLOW}=== [1] NextChat 对话前端一键部署 ===${NC}"
    install_ai_docker_probe || return

    local port=3001
    read -r -p "请输入 NextChat 访问端口 [默认 3001]: " port
    port=${port:-3001}

    # Auto-detect gateway
    local gw_url
    gw_url=$(get_gateway_url)
    local gw_key
    read -r -p "请输入 AI 网关(或代理)的 API Key [回车留空]: " gw_key
    if [ -z "$gw_url" ]; then
        read -r -p "未检测到网关，请输入 OpenAI 兼容地址 [如 http://IP:3000]: " gw_url
    fi
    [ -z "$gw_url" ] && gw_url="http://127.0.0.1:3000"

    info "正在启动 NextChat 容器..."
    if docker ps -a --format '{{.Names}}' | grep -q '^nextchat$'; then
        docker start nextchat >/dev/null 2>&1
    else
        docker run -d --name nextchat --restart always \
            -p "${port}:3000" \
            -e OPENAI_API_KEY="${gw_key:-none}" \
            -e BASE_URL="${gw_url}" \
            yidadaa/chatgpt-next-web:latest >/dev/null 2>&1
    fi

    if docker ps | grep -q 'nextchat'; then
        open_port "$port" tcp
        local ip
        ip=$(get_ip_info)
        echo ""
        success "NextChat 部署成功！"
        separator
        echo -e " ${B_GREEN}访问地址:${NC} ${B_YELLOW}http://${ip}:${port}${NC}"
        echo -e " ${B_GREEN}后端接入:${NC} ${gw_url} (Key: ${gw_key:-未设置})"
        separator
    else
        error "NextChat 容器启动失败，请检查 docker 日志与端口。"
    fi
    pause
}

install_lobechat() {
    print_banner
    echo -e "${B_YELLOW}=== [2] LobeChat 对话前端一键部署 ===${NC}"
    install_ai_docker_probe || return

    local port=3210
    read -r -p "请输入 LobeChat 访问端口 [默认 3210]: " port
    port=${port:-3210}

    info "正在启动 LobeChat 容器..."
    if docker ps -a --format '{{.Names}}' | grep -q '^lobechat$'; then
        docker start lobechat >/dev/null 2>&1
    else
        docker run -d --name lobechat --restart always \
            -p "${port}:3210" \
            lobehub/lobe-chat:latest >/dev/null 2>&1
    fi

    if docker ps | grep -q 'lobechat'; then
        open_port "$port" tcp
        local ip
        ip=$(get_ip_info)
        echo ""
        success "LobeChat 部署成功！"
        separator
        echo -e " ${B_GREEN}访问地址:${NC} ${B_YELLOW}http://${ip}:${port}${NC}"
        echo -e " ${B_CYAN}提示:${NC} 首次使用在设置里填入 AI 网关地址与 Key 即可聊天。"
        separator
    else
        error "LobeChat 容器启动失败，请检查 docker 日志与端口。"
    fi
    pause
}

menu_ai_frontend() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 AI 对话前端 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} NextChat 对话前端一键部署 (可自动接入网关)"
        echo -e " ${B_GREEN}2.${NC} LobeChat 对话前端一键部署"
        echo -e " ${B_GREEN}3.${NC} 查看前端服务运行状态"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-3]: " fe_choice
        case "$fe_choice" in
            1) install_nextchat ;;
            2) install_lobechat ;;
            3)
                echo ""
                info "当前运行状态:"
                echo -e " ${B_CYAN}nextchat:${NC} $(docker ps --filter name=nextchat --format '{{.Status}}' | head -n1 || echo '未运行')"
                echo -e " ${B_CYAN}lobechat:${NC} $(docker ps --filter name=lobechat --format '{{.Status}}' | head -n1 || echo '未运行')"
                pause
                ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
