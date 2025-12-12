#!/usr/bin/env bash
# Hysteria2 自动部署脚本（128MB 高性能 + obfs 混淆增强版）
# 适用环境：128MB RAM / IPv4 VPS
# Author: ChatGPT

set -e

HYSTERIA_VERSION="v2.6.5"
DEFAULT_PORT=22222
AUTH_PASSWORD="ieshare2025"     # 可改
SNI="www.bing.com"
ALPN="h3"

CERT_FILE="cert.pem"
KEY_FILE="key.pem"

# 自动生成 obfs 密码
OBFS_PASS="$(openssl rand -hex 12)"

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " 🚀 Hysteria2（128MB高性能版）自动安装脚本（含 obfs 混淆）"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

#--------- 获取端口 ----------
if [[ $# -ge 1 ]]; then
    SERVER_PORT="$1"
    echo "✔ 使用指定端口: $SERVER_PORT"
else
    SERVER_PORT="$DEFAULT_PORT"
    echo "ℹ 未提供端口参数，使用默认端口: $SERVER_PORT"
fi

#--------- 架构检测 ----------
arch_name() {
    local m=$(uname -m | tr '[:upper:]' '[:lower:]')
    case "$m" in
        *aarch64*|*arm64*) echo "arm64" ;;
        *x86_64*|*amd64*) echo "amd64" ;;
        *) echo "" ;;
    esac
}

ARCH=$(arch_name)
[[ -z "$ARCH" ]] && echo "❌ 无法识别 CPU 架构: $(uname -m)" && exit 1
BIN_NAME="hysteria-linux-${ARCH}"
BIN_PATH="./${BIN_NAME}"

#--------- 下载二进制 ----------
download_binary() {
    if [[ -f "$BIN_PATH" ]]; then
        echo "✔ 检测到二进制已存在，跳过下载。"
        return
    fi

    URL="https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/${BIN_NAME}"
    echo "⏳ 下载 Hysteria2: $URL"
    curl -L --retry 3 -o "$BIN_PATH" "$URL"
    chmod +x "$BIN_PATH"
    echo "✔ 下载完成: $BIN_PATH"
}

#--------- 生成证书 ----------
ensure_cert() {
    if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
        echo "✔ 已存在证书，将继续使用。"
        return
    fi

    echo "🔐 生成自签证书 ..."
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -days 3650 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=${SNI}"
    echo "✔ 证书生成成功"
}

#--------- 写 server.yaml（128MB高性能 + obfs 版本） ----------
write_config() {
cat > server.yaml <<EOF
listen: ":${SERVER_PORT}"

tls:
  cert: "$(pwd)/${CERT_FILE}"
  key: "$(pwd)/${KEY_FILE}"
  alpn:
    - "${ALPN}"

auth:
  type: password
  password: "${AUTH_PASSWORD}"

# ★★★ obfs 混淆（推荐中国大陆环境使用） ★★★
obfs:
  type: salamander
  password: "${OBFS_PASS}"

# ★★★ 128MB 内存高性能 QUIC 优化 ★★★
quic:
  max_idle_timeout: "20s"
  max_concurrent_streams: 64
  initial_stream_receive_window: 524288      # 512KB
  max_stream_receive_window: 2097152         # 2MB
  initial_conn_receive_window: 1048576       # 1MB
  max_conn_receive_window: 4194304           # 4MB

bandwidth:
  up: "500mbps"
  down: "500mbps"
EOF
    echo "✔ 写入 server.yaml 完成（高性能 + 混淆）"
}

#--------- 获取服务器 IPv4 ----------
get_server_ip() {
    curl -s --max-time 10 https://api.ipify.org || echo "YOUR_SERVER_IP"
}

#--------- 输出节点信息 ----------
print_connection_info() {
    local IP="$1"

    echo ""
    echo "🎉 Hysteria2 高性能服务器部署成功！"
    echo "============================================================="
    echo "📌 服务器信息："
    echo "   IP: ${IP}"
    echo "   PORT: ${SERVER_PORT}"
    echo "   AUTH: ${AUTH_PASSWORD}"
    echo "   OBFS: ${OBFS_PASS}"
    echo ""

    echo "📡 Hy2节点链接（含 obfs + insecure）："
    echo "hysteria2://${AUTH_PASSWORD}@${IP}:${SERVER_PORT}?obfs=salamander&obfs-password=${OBFS_PASS}&sni=${SNI}&alpn=${ALPN}&insecure=1#Hy2-OBFS"
    echo ""

    echo "📄 客户端配置（OpenClash/Mihomo 用）："
    cat <<EOF
- name: Hy2-OBFS
  type: hysteria2
  server: ${IP}
  port: ${SERVER_PORT}
  password: ${AUTH_PASSWORD}
  sni: ${SNI}
  alpn:
    - "${ALPN}"
  skip-cert-verify: true
  udp: true
  obfs:
    type: salamander
    password: "${OBFS_PASS}"
EOF

    echo "============================================================="
}

#--------- 主流程 ----------
main() {
    download_binary
    ensure_cert
    write_config

    SERVER_IP=$(get_server_ip)
    print_connection_info "$SERVER_IP"

    echo "🚀 启动 Hysteria2 服务 ..."
    exec "$BIN_PATH" server -c server.yaml
}

main "$@"
