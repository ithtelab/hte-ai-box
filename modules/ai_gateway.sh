#!/usr/bin/env bash
# ==============================================================================
# HTE-AI Box - AI Gateway & Subscription Module (new-api, sub2api)
# ==============================================================================

install_ai_docker_probe() {
    if ! command -v docker >/dev/null 2>&1; then
        warn "未检测到 Docker，建议先安装 Docker。是否现在安装？[y/N]"
        read -r -p "[y/N]: " ans
        if [[ "$ans" =~ ^[yY]$ ]]; then
            install_docker_if_missing
        else
            info "已取消。请先在主菜单按 d 安装 Docker，或手动安装。"
            pause
            return 1
        fi
    fi
    return 0
}

install_new_api() {
    print_banner
    echo -e "${B_YELLOW}=== [1] new-api AI 统一网关一键部署 ===${NC}"
    install_ai_docker_probe || return

    local data_dir="/root/hte-ai/new-api/data"
    mkdir -p "$data_dir"

    local port=3000
    read -r -p "请问 new-api 面板端口 [默认 3000]: " port
    port=${port:-3000}

    info "正在启动 new-api 容器 (默认 SQLite)..."
    if docker ps -a --format '{{.Names}}' | grep -q '^new-api$'; then
        info "检测到已存在 new-api 容器，正在重新启动..."
        docker start new-api >/dev/null 2>&1
    else
        docker run -d --name new-api --restart always \
            -p "${port}:3000" \
            -e TZ=Asia/Shanghai \
            -v "${data_dir}:/data" \
            calciumion/new-api:latest >/dev/null 2>&1
    fi

    if docker ps | grep -q 'new-api'; then
        open_port "$port" tcp
        local ip
        ip=$(get_ip_info)
        echo ""
        success "new-api 部署成功！"
        separator
        echo -e " ${B_GREEN}面板地址:${NC} ${B_YELLOW}http://${ip}:${port}${NC}"
        echo -e " ${B_GREEN}数据库:${NC}  默认 SQLite (数据保存在 ${data_dir})"
        echo -e " ${B_GREEN}首次使用:${NC} 访问上述地址 → 注册 → 初始化管理员账号并创建 API 渠道"
        separator
        echo -e " ${B_GREEN}接入前端/代理:${NC} OpenAI 兼容地址 → ${CYAN}http://${ip}:${port}${NC}"
    else
        error "new-api 容器启动失败，请检查端口占用或 docker 日志。"
    fi
    pause
}

install_sub2api() {
    print_banner
    echo -e "${B_YELLOW}=== [2] sub2api AI 订阅转换平台一键部署 ===${NC}"
    install_ai_docker_probe || return

    local deploy_dir="/root/hte-ai/sub2api"
    mkdir -p "$deploy_dir"
    cd "$deploy_dir" || { error "进入目录失败"; pause; return; }

    info "正在拉取 sub2api 官方部署脚本 (含 Postgres15 + Redis7 + Web)..."
    # Official deploy script generates docker-compose.yml + .env with secure secrets
    if curl -fsSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/docker-deploy.sh -o docker-deploy.sh; then
        bash docker-deploy.sh
    else
        # Fallback: clone repo and use its deploy dir
        info "官方部署脚本拉取失败，改用 git clone 方式..."
        git clone --depth 1 https://github.com/Wei-Shaw/sub2api.git . 2>/dev/null || true
        if [ -d deploy ]; then
            cd deploy
            [ -f .env ] || cp .env.example .env
            sed -i "s/^SERVER_PORT=.*/SERVER_PORT=8080/" .env
            sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24)/" .env
            sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/" .env
            sed -i "s/^TOTP_ENCRYPTION_KEY=.*/TOTP_ENCRYPTION_KEY=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/" .env
            docker compose -f docker-compose.local.yml up -d
        else
            error "sub2api 源码获取失败，请检查网络。"
        fi
    fi

    # Verify containers up
    if docker ps | grep -q 'sub2api'; then
        open_port 8080 tcp
        local ip
        ip=$(get_ip_info)
        echo ""
        success "sub2api 部署成功！"
        separator
        echo -e " ${B_GREEN}面板地址:${NC} ${B_YELLOW}http://${ip}:8080${NC}"
        echo -e " ${B_GREEN}依赖:${NC}   PostgreSQL 15 + Redis 7 (已自动创建)"
        echo -e " ${B_GREEN}首次使用:${NC} 首次访问网页会引导创建管理员并生成配置"
        echo -e " ${B_GREEN}配置存放:${NC} ${deploy_dir}/deploy (或仓库的 deploy 目录)"
        separator
    else
        error "sub2api 容器未运行，请检查 ${deploy_dir} 下的 docker-compose 与日志。"
    fi
    pause
}

menu_ai_gateway() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 AI 网关与订阅 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} new-api AI 统一网关一键部署 (OpenAI/Claude 兼容)"
        echo -e " ${B_GREEN}2.${NC} sub2api AI 订阅转换平台一键部署"
        echo -e " ${B_GREEN}3.${NC} 查看 new-api / sub2api 运行状态与访问地址"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-3]: " gw_choice
        case "$gw_choice" in
            1) install_new_api ;;
            2) install_sub2api ;;
            3)
                echo ""
                info "当前运行状态:"
                echo -e " ${B_CYAN}new-api:${NC} $(docker ps --filter name=new-api --format '{{.Status}}' | head -n1 || echo '未运行')"
                echo -e " ${B_CYAN}sub2api:${NC} $(docker ps --filter name=sub2api --format '{{.Status}}' | head -n1 || echo '未运行')"
                local ip
                ip=$(get_ip_info)
                echo -e " ${B_CYAN}地址:${NC} new-api http://${ip}:3000 | sub2api http://${ip}:8080"
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
