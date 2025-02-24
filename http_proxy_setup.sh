#!/bin/bash

# =============================
# HTTP Proxy 一键安装脚本 (3proxy)
# 适用于 Debian/Ubuntu
# =============================
# 用法: bash <(curl -fsSLk URL) 用户名 密码 端口1 端口2 端口3 ...
# 例子: bash <(curl -fsSLk URL) user pass 30000 30001 30002

# 检查参数
if [ "$#" -lt 3 ]; then
    echo -e "\e[91m[错误]\e[0m 用法: $0 用户名 密码 端口1 端口2 ..."
    exit 1
fi

USERNAME=$1
PASSWORD=$2
shift 2
PORTS=("$@")

# 检测系统类型
if [[ -f /etc/debian_version ]]; then
    OS="debian"
else
    echo -e "\e[91m[错误]\e[0m 不支持的系统，仅支持 Debian/Ubuntu"
    exit 1
fi

# 更新软件源并安装必要软件
apt update && apt install -y build-essential git iptables-persistent

# 手动编译安装 3proxy
cd /root
git clone https://github.com/3proxy/3proxy.git
cd 3proxy
make -f Makefile.Linux

# 安装 3proxy
mkdir -p /usr/local/etc/3proxy
cp bin/3proxy /usr/local/bin/
cp scripts/3proxy.service /etc/systemd/system/

# 获取所有公网 IP
IP_LIST=$(hostname -I | tr ' ' '\n' | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$")

# 配置 3proxy
cat > /usr/local/etc/3proxy/3proxy.cfg <<EOF
#!/usr/bin/3proxy

# 启用 HTTP 代理
auth strong
users $USERNAME:CL:$PASSWORD

$(for IP in $IP_LIST; do
    for PORT in "${PORTS[@]}"; do
        echo "proxy -n -a -p$PORT -i$IP -e$IP"
    done
done)
EOF

# 设置 3proxy 服务
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy HTTP Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启动服务并设置开机自启
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# 配置防火墙规则
if command -v ufw &>/dev/null; then
    for PORT in "${PORTS[@]}"; do
        ufw allow $PORT/tcp
    done
elif command -v iptables &>/dev/null; then
    for PORT in "${PORTS[@]}"; do
        iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
    done
    iptables-save > /etc/iptables.rules
fi

# 输出代理信息
echo -e "\e[92m[完成] HTTP 代理安装成功！\e[0m"
echo "====================================="
for IP in $IP_LIST; do
    for PORT in "${PORTS[@]}"; do
        echo "HTTP 代理地址: http://$USERNAME:$PASSWORD@$IP:$PORT"
    done
done
echo "====================================="
