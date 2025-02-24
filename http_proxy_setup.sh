#!/bin/bash

# 获取用户输入的参数（用户名、密码、端口）
USER=${1:-"proxyuser"}
PASS=${2:-"proxypass"}
PORT=${3:-30000}

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 用户运行此脚本！"
    exit 1
fi

echo "🔹 开始安装 3proxy 并配置 HTTP 代理..."
echo "🔹 用户名: $USER"
echo "🔹 密码: $PASS"
echo "🔹 端口: $PORT"

# 更新系统并安装必要的软件
apt update -y && apt install -y curl wget tar make gcc build-essential

# 下载 3proxy 并编译
cd /root
wget -qO- https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.4.tar.gz | tar xz
cd 3proxy-0.9.4
make -f Makefile.Linux
mkdir -p /usr/local/bin /usr/local/etc/3proxy
cp bin/3proxy /usr/local/bin/

# 获取所有可用 IP（IPv4）
IP_LIST=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')

# 生成 3proxy 配置文件
cat > /usr/local/etc/3proxy/3proxy.cfg <<EOF
auth strong
users $USER:CL:$PASS
allow $USER
EOF

# 为每个 IP 绑定一个端口
PORT_START=$PORT
for IP in $IP_LIST; do
    echo "proxy -n -a -p$PORT_START -i$IP -e$IP" >> /usr/local/etc/3proxy/3proxy.cfg
    echo "🔹 代理绑定: $IP:$PORT_START"
    PORT_START=$((PORT_START+1))
done

# 配置 systemd 服务
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启动 3proxy
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# 开放防火墙端口
for (( i=$PORT; i<$PORT_START; i++ )); do
    ufw allow $i/tcp
done
ufw reload

echo "✅ HTTP 代理安装完成！"
echo "📌 代理地址:"
PORT_START=$PORT
for IP in $IP_LIST; do
    echo "🔹 http://$USER:$PASS@$IP:$PORT_START"
    PORT_START=$((PORT_START+1))
done
