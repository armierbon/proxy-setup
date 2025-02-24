#!/bin/bash

# 颜色
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}请使用 root 用户运行此脚本！${RESET}"
   exit 1
fi

# 交互式输入用户名、密码、端口
read -p "请输入代理用户名: " USER
read -s -p "请输入代理密码: " PASS
echo ""
read -p "请输入起始端口号 (默认 30000): " START_PORT
START_PORT=${START_PORT:-30000}

# 获取 VPS 的所有公网 IPv4 地址
IP_LIST=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1)

echo -e "${GREEN}正在安装 3proxy...${RESET}"

# 安装必要组件
if [[ -f /etc/debian_version ]]; then
    apt update -y && apt install -y build-essential wget tar
elif [[ -f /etc/redhat-release ]]; then
    yum install -y gcc make wget tar
else
    echo -e "${RED}不支持的操作系统${RESET}"
    exit 1
fi

# 下载并编译 3proxy
cd /root
wget -qO 3proxy.tar.gz https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.4.tar.gz
tar -xzf 3proxy.tar.gz
cd 3proxy-0.9.4
make -f Makefile.Linux
cp bin/3proxy /usr/local/bin/
chmod +x /usr/local/bin/3proxy

# 配置 3proxy
mkdir -p /usr/local/etc/3proxy
cat > /usr/local/etc/3proxy/3proxy.cfg <<EOF
daemon
auth strong
users ${USER}:CL:${PASS}
EOF

PORT=$START_PORT
for IP in $IP_LIST; do
    echo "proxy -n -a -p${PORT} -i${IP} -e${IP}" >> /usr/local/etc/3proxy/3proxy.cfg
    PORT=$((PORT + 1))
done

# 创建 systemd 服务
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3Proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 启动 3proxy
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# 显示代理信息
echo -e "${GREEN}HTTP 代理已安装并运行！${RESET}"
echo "============================="
PORT=$START_PORT
for IP in $IP_LIST; do
    echo "http://${USER}:${PASS}@${IP}:${PORT}"
    PORT=$((PORT + 1))
done
echo "============================="
