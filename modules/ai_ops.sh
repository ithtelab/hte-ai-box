#!/usr/bin/env bash
# ==============================================================================
# HTE-AI Box - Public Exposure & Ops Module (Cloudflare Tunnel, Backup, TG)
# ==============================================================================

install_cloudflared_tunnel() {
    print_banner
    echo -e "${B_YELLOW}=== [1] Cloudflare Tunnel 一键公网暴露面板 ===${NC}"
    info "无需开放端口/自带 HTTPS，专治面板被运营商封 80/443"

    if ! command -v cloudflared >/dev/null 2>&1; then
        info "正在安装 cloudflared (Docker 容器方式)..."
        docker pull cloudflare/cloudflared:latest >/dev/null 2>&1 || true
    fi

    # Quick tunnel (no account) for instant exposure, or named tunnel with token
    echo -e " ${B_GREEN}1.${NC} 快速隧道 (Quick Tunnel, 无需域名/账号, 一次性随机地址)"
    echo -e " ${B_GREEN}2.${NC} 命名隧道 (需 Cloudflare 账号 Token, 绑定自有域名)"
    echo -e " ${B_RED}0.${NC} 返回"
    echo ""
    read -r -p "请选择 [0-2]: " cf_choice

    case "$cf_choice" in
        1)
            local target_port
            read -r -p "请输入要暴露的内部端口 (如 new-api 3000 / 面板 8085): " target_port
            [ -z "$target_port" ] && target_port="3000"
            info "正在启动快速隧道 (临时公网地址)..."
            docker rm -f hte-tunnel 2>/dev/null || true
            docker run -d --name hte-tunnel --restart unless-stopped \
                cloudflare/cloudflared:latest tunnel --no-autoupdate \
                --url "http://localhost:${target_port}" >/dev/null 2>&1
            sleep 5
            local cf_url
            cf_url=$(docker logs hte-tunnel 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -n1)
            if [ -n "$cf_url" ]; then
                echo ""
                success "快速隧道已生成！"
                separator
                echo -e " ${B_GREEN}公网访问地址:${NC} ${B_YELLOW}${cf_url}${NC}  (临时, 重启后失效)"
                echo -e " ${B_CYAN}提示:${NC} Cloudflare Tunnel 自动提供 HTTPS，无需在服务器开放端口。"
                separator
            else
                warn "未获取到快速隧道地址，请稍后执行 docker logs hte-tunnel 查看。"
            fi
            ;;
        2)
            read -r -p "请输入 Cloudflare Tunnel Token: " cf_token
            if [ -n "$cf_token" ]; then
                info "正在启动命名隧道..."
                docker rm -f hte-tunnel 2>/dev/null || true
                docker run -d --name hte-tunnel --restart unless-stopped \
                    cloudflare/cloudflared:latest tunnel --no-autoupdate run --token "$cf_token" >/dev/null 2>&1
                success "命名隧道启动中，请到 Cloudflare Zero Trust 后台查看你配置的公网地址。"
            else
                error "Token 不能为空！"
            fi
            ;;
        *) return ;;
    esac
    pause
}

backup_ai_config() {
    print_banner
    echo -e "${B_YELLOW}=== [2] AI 配置一键备份导出 ===${NC}"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local dest="/root/hte-ai-backup_${ts}.tar.gz"

    info "正在收集 AI 相关配置与数据..."
    local has_data=0
    local list_file="/tmp/hte_ai_backup_list.txt"
    : > "$list_file"

    if [ -d /root/hte-ai ]; then
        echo "/root/hte-ai" >> "$list_file"; has_data=1
    fi
    if [ -f /root/hte-ai/cli-proxy/config.yaml ]; then
        echo "/root/hte-ai/cli-proxy/config.yaml" >> "$list_file"; has_data=1
    fi
    # new-api data
    if [ -d /root/hte-ai/new-api/data ]; then
        echo "/root/hte-ai/new-api/data" >> "$list_file"; has_data=1
    fi

    if [ "$has_data" -eq 0 ]; then
        warn "未检测到 /root/hte-ai 下的 AI 配置，可能尚未部署任何项目。"
        pause
        return
    fi

    info "正在打包 (排除数据卷大文件)..."
    tar --exclude='/var' --exclude='/usr' --exclude='/proc' --exclude='/sys' \
        -czf "$dest" -T "$list_file" >/dev/null 2>&1
    rm -f "$list_file"

    if [ -f "$dest" ]; then
        local size
        size=$(du -h "$dest" | cut -f1)
        echo ""
        success "AI 配置备份完成！"
        separator
        echo -e " ${B_GREEN}备份文件:${NC} ${B_YELLOW}${dest}${NC} (大小 ${size})"
        echo -e " ${B_CYAN}包含:${NC} /root/hte-ai 下的网关/前端/代理配置与数据"
        separator
    else
        error "备份失败，请检查磁盘空间。"
    fi
    pause
}

setup_ai_telegram() {
    print_banner
    echo -e "${B_YELLOW}=== [3] Telegram 告警推送 (网关报错/余额不足) ===${NC}"
    read -r -p "请输入 Telegram Bot Token: " tg_token
    read -r -p "请输入接收告警的 Chat ID: " tg_chat
    if [ -z "$tg_token" ] || [ -z "$tg_chat" ]; then
        error "Token 与 Chat ID 不能为空！"
        pause
        return
    fi

    local conf="/etc/hte-ai-alert.conf"
    cat <<EOF > "$conf"
TG_TOKEN="${tg_token}"
TG_CHAT="${tg_chat}"
EOF
    chmod 600 "$conf"

    # Test connectivity
    info "正在测试 Telegram Bot 连通性..."
    local resp
    resp=$(curl -s --connect-timeout 8 --max-time 15 "https://api.telegram.org/bot${tg_token}/sendMessage" --data-urlencode "chat_id=${tg_chat}" --data-urlencode "text=✅ 黑天鹅 AI 工具箱 Telegram 告警配置成功!" 2>/dev/null)
    if echo "$resp" | grep -q '"ok":true'; then
        success "Telegram Bot 连通成功！"
    else
        error "连通失败，请检查 Token / Chat ID 或服务器能否访问 api.telegram.org"
        pause
        return
    fi

    # Install a small periodic health-check helper using the existing open_port infra
    local helper="/usr/local/bin/hte-ai-alert"
    cat <<'HEOF' > "$helper"
#!/usr/bin/env bash
[ -f /etc/hte-ai-alert.conf ] && . /etc/hte-ai-alert.conf
send() {
    [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT" ] && return 1
    curl -s --max-time 10 "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" --data-urlencode "text=$1" >/dev/null 2>&1
}
# Check key containers health
for name in new-api sub2api cli-proxy-api ollama; do
    st=$(docker ps --filter name="$name" --format '{{.Names}}' | grep -qx "$name" 2>/dev/null && echo up || echo down)
    if [ "$st" = "down" ]; then
        send "⚠️ AI 服务 ${name} 已停止运行！"
    fi
done
HEOF
    chmod +x "$helper"
    # cron every 5 min
    echo "*/5 * * * * ${helper}" | crontab - 2>/dev/null || echo "*/5 * * * * /usr/local/bin/hte-ai-alert" > /etc/cron.d/hte-ai-alert

    success "Telegram 告警配置完成！每5分钟检查 AI 服务，异常时推送到 TG。"
    pause
}

menu_ai_ops() {
    while true; do
        print_banner
        echo -e "${B_CYAN}【 公网暴露与运维 】${NC}"
        separator
        echo -e " ${B_GREEN}1.${NC} Cloudflare Tunnel 一键公网暴露面板 (免开端口/HTTPS)"
        echo -e " ${B_GREEN}2.${NC} AI 配置一键备份导出"
        echo -e " ${B_GREEN}3.${NC} Telegram 告警推送 (服务异常通知)"
        separator
        echo -e " ${B_RED}0.${NC} 返回主菜单"
        echo ""
        read -r -p "请输入选项 [0-3]: " ops_choice
        case "$ops_choice" in
            1) install_cloudflared_tunnel ;;
            2) backup_ai_config ;;
            3) setup_ai_telegram ;;
            0) break ;;
            *)
                echo -e "${RED}输入错误，请重新选择！${NC}"
                sleep 1
                ;;
        esac
    done
}
