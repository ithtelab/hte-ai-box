#!/usr/bin/env bash
# ==============================================================================
# HTE-AI Box - CLI Proxy & Local Inference Module (CLIProxyAPI cpa, Ollama)
# ==============================================================================

install_cli_proxy_api() {
    print_banner
    echo -e "${B_YELLOW}=== [1] CLIProxyAPI (cpa) Claude/OpenAI CLI 中转一键部署 ===${NC}"
    install_ai_docker_probe || return

    local deploy_dir="/root/hte-ai/cli-proxy"
    mkdir -p "$deploy_dir/configs"
    cd "$deploy_dir" || { error "进入部署目录失败"; pause; return; }

    # Build config.yaml: instruct user to fill upstream keys
    local config_file="${deploy_dir}/config.yaml"
    if [ ! -f "$config_file" ]; then
        cat <<'YEOF' > "$config_file"
# CLIProxyAPI config — fill in your upstream API keys below.
# See https://help.router-for.me/ for full option reference.
openai:
  api_key: "YOUR_OPENAI_API_KEY"
  base_url: "https://api.openai.com"
anthropic:
  api_key: "YOUR_ANTHROPIC_API_KEY"
  base_url: "https://api.anthropic.com"
# Optional: proxy, github token, codex endpoint, etc.
# proxy: "http://user:pass@host:port"
YEOF
        info "已生成示例 config.yaml，请打开 ${config_file} 填入上游 API Key。"
    fi

    local mgmt_pass
    read -r -p "请设置 cpa 管理面板密码 [默认随机生成]: " mgmt_pass
    if [ -z "$mgmt_pass" ]; then
        mgmt_pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)
    fi

    # Write docker-compose.yml (mirrors official ports)
    cat <<EOF > "${deploy_dir}/docker-compose.yml"
services:
  cli-proxy-api:
    image: eceasy/cli-proxy-api:latest
    pull_policy: always
    container_name: cli-proxy-api
    environment:
      MANAGEMENT_PASSWORD: "${mgmt_pass}"
    ports:
      - "8085:8085"      # Management Web UI
      - "8317:8317"      # API / endpoint
      - "1455:1455"
      - "54545:54545"
      - "51121:51121"
      - "11451:11451"
    volumes:
      - "${config_file}:/CLIProxyAPI/config.yaml"
      - "${deploy_dir}/auths:/root/.cli-proxy-api"
      - "${deploy_dir}/logs:/CLIProxyAPI/logs"
      - "${deploy_dir}/plugins:/CLIProxyAPI/plugins"
    restart: unless-stopped
EOF

    info "正在启动 CLIProxyAPI 容器..."
    if docker compose -f "${deploy_dir}/docker-compose.yml" up -d >/dev/null 2>&1; then
        open_port 8085 tcp
        open_port 8317 tcp
        local ip
        ip=$(get_ip_info)
        echo ""
        success "CLIProxyAPI (cpa) 部署成功！"
        separator
        echo -e " ${B_GREEN}管理面板:${NC} ${B_YELLOW}http://${ip}:8085${NC}"
        echo -e " ${B_GREEN}API 地址:${NC} ${B_YELLOW}http://${ip}:8317${NC}"
        echo -e " ${B_GREEN}面板密码:${NC} ${B_YELLOW}${mgmt_pass}${NC}"
        echo -e " ${B_GREEN}配置文件:${NC} ${config_file}"
        echo -e " ${B_CYAN}提示:${NC} 请先在 config.yaml 填入上游 API Key，再前往面板绑定密钥。"
        separator
    else
        error "CLIProxyAPI 容器启动失败，请检查 docker 日志。"
        echo -e " ${B_CYAN}可尝试:${NC} docker compose -f ${deploy_dir}/docker-compose.yml logs"
    fi
    pause
}

install_ollama() {
    print_banner
    echo -e "${B_YELLOW}=== [2] Ollama 本地大模型推理一键部署 ===${NC}"
    install_ai_docker_probe || return

    local port=11434
    read -r -p "请输入 Ollama 服务端口 [默认 11434]: " port
    port=${port:-11434}

    local data_dir="/root/hte-ai/ollama"
    mkdir -p "$data_dir"

    info "正在启动 Ollama 容器..."
    if docker ps -a --format '{{.Names}}' | grep -q '^ollama$'; then
        docker start ollama >/dev/null 2>&1
    else
        docker run -d --name ollama --restart always \
            -p "${port}:11434" \
            -v "${data_dir}:/root/.ollama" \
            ollama/ollama:latest >/dev/null 2>&1
    fi

    if docker ps | grep -q 'ollama'; then
        open_port "$port" tcp
        local ip
        ip=$(get_ip_info)
        local model
        read -r -p "是否立即拉取一个模型？[如 qwen:7b / llama3.1:8b，回车跳过]: " model
        if [ -n "$model" ]; then
            info "正在拉取模型 ${model} (视网速可能较慢)..."
            docker exec ollama ollama pull "$model" 2>&1 | tail -n 5
        fi
        echo ""
        success "Ollama 部署成功！"
        separator
        echo -e " ${B_GREEN}服务地址:${NC} ${B_YELLOW}http://${ip}:${port}${NC}"
        echo -e " ${B_GREEN}API 兼容:${NC} OpenAI 兼容接口 (模型 ${model:-待拉取})"
        echo -e " ${B_GREEN}数据目录:${NC} ${data_dir}"
        separator
    else
        error "Ollama 容器启动失败，请检查 docker 日志。"
    fi
    pause
}

menu_ai_proxy() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 中转与本地推理 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} CLIProxyAPI (cpa) Claude/OpenAI CLI 中转一键部署"
        echo -e " ${B_GREEN}2.${NC} Ollama 本地大模型推理一键部署"
        echo -e " ${B_GREEN}3.${NC} 查看中转/推理服务运行状态"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-3]: " px_choice
        case "$px_choice" in
            1) install_cli_proxy_api ;;
            2) install_ollama ;;
            3)
                echo ""
                info "当前运行状态:"
                echo -e " ${B_CYAN}cli-proxy-api:${NC} $(docker ps --filter name=cli-proxy-api --format '{{.Status}}' | head -n1 || echo '未运行')"
                echo -e " ${B_CYAN}ollama:${NC} $(docker ps --filter name=ollama --format '{{.Status}}' | head -n1 || echo '未运行')"
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
