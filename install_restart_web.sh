#!/bin/bash

# VPS 一键重启网页服务安装脚本
# 适用于 Debian 12

set -e

echo "=========================================="
echo "VPS 网页重启服务 - 一键安装脚本"
echo "=========================================="
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then 
    echo "错误: 请使用 root 权限运行此脚本"
    echo "使用命令: sudo bash install_restart_web.sh"
    exit 1
fi

# 设置安装目录
INSTALL_DIR="/opt/restart_web"
SERVICE_PORT=5000

echo "[1/6] 更新系统包列表..."
apt update -qq

echo "[2/6] 检查并安装 Python3..."
if ! command -v python3 &> /dev/null; then
    echo "正在安装 Python3..."
    apt install python3 -y
else
    echo "Python3 已安装:  $(python3 --version)"
fi

echo "[3/6] 创建安装目录..."
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

echo "[4/6] 创建 HTML 文件..."
cat > $INSTALL_DIR/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>重启 VPS</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background:  linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 400px;
        }
        h1 {
            color: #333;
            margin-bottom:  20px;
        }
        p {
            color: #666;
            margin-bottom: 30px;
        }
        button {
            padding: 15px 30px;
            font-size: 16px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            transition: background 0.3s;
        }
        button:hover {
            background: #764ba2;
        }
        #status {
            margin-top: 20px;
            padding: 10px;
            border-radius: 5px;
            font-weight: bold;
        }
        .success {
            background: #d4edda;
            color: #155724;
        }
        .error {
            background: #f8d7da;
            color: #721c24;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔄 重启 VPS</h1>
        <p>点击下面的按钮来重启此 VPS 服务器</p>
        <button onclick="restart()">立即重启</button>
        <p id="status"></p>
    </div>
    
    <script>
        function restart() {
            if(confirm('确定要重启 VPS 吗？\n\n服务器将会立即重启，所有连接将会断开。')) {
                const statusEl = document.getElementById('status');
                statusEl.innerText = '正在发送重启命令...';
                statusEl.className = '';
                
                fetch('/restart')
                    .then(response => response.text())
                    .then(data => {
                        statusEl.innerText = '✅ ' + data;
                        statusEl.className = 'success';
                    })
                    .catch(error => {
                        statusEl.innerText = '❌ 重启失败: ' + error;
                        statusEl.className = 'error';
                    });
            }
        }
    </script>
</body>
</html>
EOF

echo "[5/6] 创建 Python 服务器脚本..."
cat > $INSTALL_DIR/restart_server.py << 'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import os

class RestartHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/': 
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            try:
                with open('/opt/restart_web/index.html', 'rb') as f:
                    self.wfile. write(f.read())
            except Exception as e:
                self.wfile.write(f'Error loading page: {e}'.encode('utf-8'))
                
        elif self.path == '/restart':
            try:
                # 发送重启命令
                subprocess.Popen(['/sbin/reboot'])
                self. send_response(200)
                self.send_header('Content-type', 'text/plain; charset=utf-8')
                self.end_headers()
                self.wfile.write('重启命令已成功发送！服务器即将重启... '.encode('utf-8'))
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'text/plain; charset=utf-8')
                self.end_headers()
                self.wfile.write(f'重启失败:  {e}'.encode('utf-8'))
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'404 Not Found')
    
    def log_message(self, format, *args):
        print(f"{self.address_string()} - [{self.log_date_time_string()}] {format%args}")

if __name__ == '__main__': 
    port = 5000
    server = HTTPServer(('0.0.0.0', port), RestartHandler)
    print(f'========================================')
    print(f'VPS 重启服务已启动')
    print(f'访问地址: http://0.0.0.0:{port}')
    print(f'========================================')
    server.serve_forever()
EOF

chmod +x $INSTALL_DIR/restart_server.py

echo "[6/6] 创建并启动 systemd 服务..."
cat > /etc/systemd/system/restart_web.service << EOF
[Unit]
Description=VPS Web Restart Service
After=network. target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $INSTALL_DIR/restart_server.py
Restart=always
RestartSec=10
User=root
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd
systemctl daemon-reload

# 启用服务（开机自启）
systemctl enable restart_web.service

# 启动服务
systemctl start restart_web.service

# 等待服务启动
sleep 2

echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo ""
echo "服务信息："
echo "  - 安装目录: $INSTALL_DIR"
echo "  - 服务端口: $SERVICE_PORT"
echo "  - 服务状态: $(systemctl is-active restart_web.service)"
echo ""
echo "访问地址："
echo "  - 本地:  http://localhost:$SERVICE_PORT"
echo "  - 外网: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的服务器IP'):$SERVICE_PORT"
echo ""
echo "常用命令："
echo "  - 查看服务状态: systemctl status restart_web"
echo "  - 停止服务: systemctl stop restart_web"
echo "  - 启动服务: systemctl start restart_web"
echo "  - 重启服务: systemctl restart restart_web"
echo "  - 查看日志: journalctl -u restart_web -f"
echo "  - 卸载服务: systemctl stop restart_web && systemctl disable restart_web && rm /etc/systemd/system/restart_web.service"
echo ""
echo "=========================================="

# 显示服务状态
echo ""
echo "当前服务状态："
systemctl status restart_web.service --no-pager