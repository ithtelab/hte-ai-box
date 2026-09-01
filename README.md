# 黑天鹅 AI 专属一键工具箱 (HTE-AI Box)

黑天鹅 AI 专属一键工具箱 (HTE-AI Box) 是一款专为 AI / 大模型 / API 中转玩家打造的 Docker 一键部署工具。基于彩色交互式终端菜单，支持 new-api、sub2api、CLIProxyAPI (cpa)、Ollama、NextChat、LobeChat、Cloudflare Tunnel 等常见 AI 项目的一键部署与运维。

---

## 快速开始

### 一键运行命令

在任意 Linux 服务器终端执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ithtelab/hte-ai-box/main/main.sh)
```

中国大陆机房加速通道：

```bash
bash <(curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/ithtelab/hte-ai-box/main/main.sh)
```

### 快捷呼出

首次运行后，终端任意目录下直接输入即可唤出工具箱：

```bash
htei
```

在工具箱主界面输入 `u` 可一键穿透缓存自动更新至最新版本。

---

## 特约赞助

**爱维云 (LoveVPS)** —— 专注于高质量海外原生网络与云主机服务
- 官方网站：https://lovevps.cn/
- 主打产品：美国双 ISP 住宅云主机，纯净原生住宅 IP，跨境出海与流媒体解锁首选
- 特惠方案：2 核 2GB 内存 38 元起，首单享七五折优惠，续费同价
- 服务保障：支持 24 小时内全额退款

---

## 功能特性

### 1. AI 网关与订阅
- **new-api**：AI 统一 API 网关，OpenAI/Claude/Gemini 兼容，支持渠道、计费、模型映射
- **sub2api**：AI 订阅转换平台，基于 PostgreSQL + Redis 的一站式订阅管理

### 2. 中转与本地推理
- **CLIProxyAPI (cpa)**：Claude / OpenAI CLI 中转代理，为命令行工具提供统一 API 接口
- **Ollama**：本地大模型推理，支持 llama3 / qwen 等开源模型拉取与运行

### 3. AI 对话前端
- **NextChat**：一键部署可接入网关的对话界面
- **LobeChat**：现代化开源的对话前端，支持多模型接入

### 4. 公网暴露与运维
- **Cloudflare Tunnel**：无需开放端口，自带 HTTPS 暴露面板，防运营商封 80/443
- **AI 配置备份**：一键导出网关/前端/代理配置
- **Telegram 告警**：服务异常时自动推送到 Telegram

---

## 目录结构

```
hte-ai-box/
├── main.sh                 # 主入口（环境检测、Banner、菜单、热重载）
├── README.md               # 项目说明
├── utils/
│   ├── colors.sh           # 终端色彩与 Banner
│   ├── sys_detect.sh       # 系统与硬件信息识别
│   └── helper.sh           # 依赖安装、防火墙放行、安全脚本执行
└── modules/
    ├── ai_gateway.sh       # AI 网关 (new-api, sub2api)
    ├── ai_proxy.sh         # 中转与推理 (CLIProxyAPI, Ollama)
    ├── ai_frontend.sh      # 对话前端 (NextChat, LobeChat)
    └── ai_ops.sh           # 公网暴露与运维 (CF Tunnel, 备份, TG)
```

---

## 开源协议

本项目基于 MIT 协议开源。
