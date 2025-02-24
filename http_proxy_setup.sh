#!/bin/bash

# =============================
# HTTP Proxy 一键安装脚本 (3proxy)
# =============================
# 用法: bash <(curl -fsSLk URL) 用户名 密码 端口

# 检查参数
if [ "$#" -ne 3 ]; then
    echo -e "\e[91m[错误]\e[0m 用法: $0 用户名 密码 端口"
    exit 1
fi

USERNAME=$1
PASSWORD=$2
PORT=$3

# 检测系统类型
if [[ -f /etc/debian_version ]]; then
    OS="debian"
elif [[ -f /etc/redhat-release ]]; then
    OS="centos"
else
    echo -e "\e[91m[错误]\e[0m 不支持的系统"
    exit 1
fi

# 安装 3proxy
if [[ "$OS" == "debian" ]]; then
    apt update && apt install -y 3proxy iptables-persistent
elif [[ "$OS" == "centos" ]]; then
    yum install -y epel-release && yum install -y 3proxy
fi

# 获取所有公网 IP
IP_LIST=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')

# 配置 3proxy
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
#!/usr/bin/3proxy

# 启用 HTTP 代理
auth strong
users $USERNAME:CL:$PASSWORD
EOF

for IP in $IP_LIST; do
    echo "proxy -n -a -p$PORT -i$IP -e$IP" >> /etc/3proxy/3proxy.cfg
done

# 设置 3proxy 服务
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy HTTP Proxy
After=network.target

[Service]
ExecStart=/usr/sbin/3proxy /etc/3proxy/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启动服务并设置开机自启
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# 配置防火墙
if command -v ufw &>/dev/null; then
    ufw allow $PORT/tcp
elif command -v iptables &>/dev/null; then
    iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
    iptables-save > /etc/iptables.rules
    netfilter-persistent save
fi

# 输出代理信息
echo -e "\e[92m[完成] HTTP 代理安装成功！\e[0m"
echo "====================================="
for IP in $IP_LIST; do
    echo "HTTP 代理地址: http://$USERNAME:$PASSWORD@$IP:$PORT"
done
echo "====================================="
