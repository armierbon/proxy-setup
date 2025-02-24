#!/bin/bash

# =============================
# HTTP Proxy 一键安装脚本 (3proxy)
# =============================
# 用法: bash <(curl -fsSLk URL) 用户名 密码 端口

# 检查参数
if [ "$#" -ne 3 ]; then
    echo "\e[91m[错误]\e[0m 用法: $0 用户名 密码 端口"
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
    echo "\e[91m[错误]\e[0m 不支持的系统"
    exit 1
fi

# 安装必要软件
if [[ "$OS" == "debian" ]]; then
    apt update
    apt install -y build-essential git iptables-persistent netfilter-persistent
    cd /root
    git clone https://github.com/3proxy/3proxy.git
    cd 3proxy
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy
    cp src/3proxy /usr/local/bin/
    cp scripts/3proxy.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable 3proxy
    systemctl restart 3proxy
elif [[ "$OS" == "centos" ]]; then
    yum install -y epel-release
    yum install -y gcc make git
    cd /root
    git clone https://github.com/3proxy/3proxy.git
    cd 3proxy
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy
    cp src/3proxy /usr/local/bin/
    cp scripts/3proxy.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable 3proxy
    systemctl restart 3proxy
fi

# 获取所有公网 IP
IP_LIST=$(hostname -I | tr ' ' '\n' | grep -E "^[0-9]+")

# 配置 3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
#!/usr/bin/3proxy

auth strong
users $USERNAME:CL:$PASSWORD

$(for IP in $IP_LIST; do
    echo "proxy -n -a -p$PORT -i$IP -e$IP"
done)
EOF

# 设置 3proxy 服务
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy HTTP Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# 配置防火墙
if command -v ufw &>/dev/null; then
    ufw allow $PORT/tcp
elif command -v iptables &>/dev/null; then
    iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
    iptables-save > /etc/iptables.rules
fi

# 保存防火墙规则（解决 `netfilter-persistent` 问题）
netfilter-persistent save
netfilter-persistent reload

# 输出代理信息
echo "\e[92m[完成] HTTP 代理安装成功！\e[0m"
echo "====================================="
for IP in $IP_LIST; do
    echo "HTTP 代理地址: http://$USERNAME:$PASSWORD@$IP:$PORT"
done
echo "====================================="
