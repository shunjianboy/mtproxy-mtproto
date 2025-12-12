#!/bin/bash

# VPS 网页重启服务 - 卸载脚本

set -e

echo "=========================================="
echo "VPS 网页重启服务 - 卸载脚本"
echo "=========================================="
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then 
    echo "错误: 请使用 root 权限运行此脚本"
    echo "使用命令: sudo bash uninstall_restart_web.sh"
    exit 1
fi

read -p "确定要卸载 VPS 网页重启服务吗？(y/N) " -n 1 -r
echo
if [[ !  $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消卸载"
    exit 0
fi

echo "[1/4] 停止服务..."
systemctl stop restart_web. service 2>/dev/null || true

echo "[2/4] 禁用服务..."
systemctl disable restart_web.service 2>/dev/null || true

echo "[3/4] 删除服务文件..."
rm -f /etc/systemd/system/restart_web.service
systemctl daemon-reload

echo "[4/4] 删除程序文件..."
rm -rf /opt/restart_web

echo ""
echo "=========================================="
echo "✅ 卸载完成！"
echo "=========================================="