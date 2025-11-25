#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在安装..."
    curl -fsSL https://get.docker.com | bash
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose 未安装，正在安装..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

echo "================================================="
echo "       MTProxy 升级版安装脚本 (基于 alexbers)"
echo "================================================="

# 获取当前目录
WORK_DIR=$(pwd)

read -e -p "请输入链接端口(默认443) :" port
[[ -z "${port}" ]] && port="443"

read -e -p "请输入伪装域名(默认 www.microsoft.com) :" domain
[[ -z "${domain}" ]] && domain="www.microsoft.com"

# 生成 Secret
# 新版 MTProxy 推荐使用带伪装头的 Secret (以 ee 开头)
random_hex=$(cat /proc/sys/kernel/random/uuid | sed 's/-//g')
domain_hex=$(echo -n "$domain" | xxd -ps | tr -d '\n')
# 构造秘钥: ee + 随机32位 + 域名hex
secret="ee${random_hex}${domain_hex}"

echo -e "生成的完整密钥: \033[32m$secret\033[0m"

read -rp "你需要TAG标签吗(推广引流用)? (Y/N): " chrony_install
tag=""
[[ -z ${chrony_install} ]] && chrony_install="N"
case $chrony_install in
    [yY][eE][sS] | [yY])
        read -e -p "请输入TAG:" tag
        ;;
esac

# 生成 docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3'
services:
  mtproxy:
    image: alexbers/mtproxy:latest
    container_name: mtproxy
    restart: always
    network_mode: "host"
    volumes:
      - ./config:/data
    command: -p $port -d $domain -s $secret $tag
EOF

echo -e "正在启动 MTProxy..."
docker-compose up -d

# 获取本机 IP
public_ip=$(curl -s http://ipv4.icanhazip.com)
[ -z "$public_ip" ] && public_ip=$(curl -s ipinfo.io/ip --ipv4)

echo -e "\n================================================="
echo -e "安装完成！"
echo -e "服务器IP：\033[31m$public_ip\033[0m"
echo -e "服务器端口：\033[31m$port\033[0m"
echo -e "MTProxy Secret: \033[31m$secret\033[0m"
echo -e "TG一键链接: https://t.me/proxy?server=${public_ip}&port=${port}&secret=${secret}"
echo -e "=================================================\n"