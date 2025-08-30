#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 变量定义
PROJECT_DIR="$HOME/python-xray-argo"
LUNES_DIR="$HOME/lunes-monitor"
NODE_INFO_FILE="$HOME/.xray_nodes_info"
UUID="f674ae97-7fd2-4b40-8d92-8e853b9ec5b5"  # 默认 UUID
CFIP="joeyblog.net"
CFPORT="443"
ARGO_PORT="443"
WS_URL="wss://betadash.lunes.host/api/websocket"  # 假设的 lunes.host WebSocket URL

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}此脚本需要 root 权限，请使用 sudo 运行${NC}"
    exit 1
fi

# 确认操作
echo -e "${YELLOW}此脚本将部署 Python Xray Argo 和 lunes-monitor 服务${NC}"
echo -e "${YELLOW}优化 YouTube 分流并适配 lunes.host (Python 3.13.7)${NC}"
echo -e "${YELLOW}继续? (y/n): ${NC}"
read -p "> " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${GREEN}操作取消${NC}"
    exit 0
fi

# 安装依赖
echo -e "${BLUE}检查并安装依赖 (Python 3.13.7)...${NC}"
if ! command -v python3.13 &> /dev/null; then
    echo -e "${YELLOW}安装 Python 3.13.7...${NC}"
    apt-get update
    apt-get install -y software-properties-common
    add-apt-repository ppa:deadsnakes/ppa
    apt-get install -y python3.13 python3.13-dev python3.13-venv python3.13-distutils
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1
fi
if ! python3.13 -m pip --version &> /dev/null; then
    echo -e "${YELLOW}安装 pip for Python 3.13.7...${NC}"
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13
fi

# 安装项目依赖
echo -e "${BLUE}安装 Python 依赖...${NC}"
python3.13 -m pip install --upgrade pip
python3.13 -m pip install requests selenium

# 克隆或更新项目
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载 Python Xray Argo 项目...${NC}"
    git clone https://github.com/eooce/python-xray-argo.git "$PROJECT_DIR" || {
        echo -e "${RED}Git 克隆失败，尝试 wget...${NC}"
        wget -q https://github.com/eooce/python-xray-argo/archive/main.zip -O temp.zip
        unzip -q temp.zip
        mv python-xray-argo-main "$PROJECT_DIR"
        rm temp.zip
    }
else
    echo -e "${BLUE}更新现有项目...${NC}"
    cd "$PROJECT_DIR" && git pull
fi

# 设置 lunes-monitor 目录
if [ ! -d "$LUNES_DIR" ]; then
    mkdir -p "$LUNES_DIR"
fi
cd "$LUNES_DIR" || exit 1

# 创建或更新 lunes_login.py
echo -e "${BLUE}创建/更新 lunes_login.py...${NC}"
cat > lunes_login.py << 'EOF'
#!/usr/bin/env python3.13
import os
import time
import logging
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from websocket import create_connection

# 配置日志
logging.basicConfig(filename='logs/lunes_monitor.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# 环境变量
USERNAME = os.environ.get('LUNES_USERNAME', 'mmmjheng@gmail.com')
PASSWORD = os.environ.get('LUNES_PASSWORD', '近哈IJR!')
CHECK_INTERVAL = int(os.environ.get('CHECK_INTERVAL', 30))
MAX_RETRIES = int(os.environ.get('MAX_RETRIES', 3))
WS_URL = os.environ.get('WS_URL', 'wss://betadash.lunes.host/api/websocket')

def setup_driver():
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    driver = webdriver.Chrome(options=chrome_options)
    return driver

def login_lunes(driver):
    try:
        driver.get('https://betadash.lunes.host/login')
        logging.info("正在访问 betadash 登录页面")
        time.sleep(2)
        driver.find_element(By.ID, 'username').send_keys(USERNAME)
        driver.find_element(By.ID, 'password').send_keys(PASSWORD)
        driver.find_element(By.XPATH, '//button[@type="submit"]').click()
        logging.info("登录尝试完成")
        time.sleep(5)  # 等待登录
        if "dashboard" in driver.current_url:
            logging.info("登录成功")
            return True
        return False
    except Exception as e:
        logging.error(f"登录失败: {e}")
        return False

def monitor_websocket():
    retries = 0
    while retries < MAX_RETRIES:
        try:
            ws = create_connection(WS_URL)
            logging.info(f"WebSocket 连接成功: {WS_URL}")
            while True:
                message = ws.recv()
                logging.info(f"收到消息: {message}")
                time.sleep(CHECK_INTERVAL)
        except Exception as e:
            logging.error(f"WebSocket 错误: {e}")
            retries += 1
            time.sleep(5)
    logging.error("WebSocket 连接失败，达到最大重试次数")

if __name__ == "__main__":
    driver = setup_driver()
    if login_lunes(driver):
        monitor_websocket()
    driver.quit()
EOF
chmod +x lunes_login.py

# 创建 Docker Compose 文件
echo -e "${BLUE}创建 docker-compose.yml...${NC}"
cat > docker-compose.yml << 'EOF'
services:
  monitor:
    build: .
    container_name: lunes-monitor
    command: ["python3.13", "/app/lunes_login.py"]
    volumes:
      - ./logs:/app/logs
    environment:
      - LUNES_USERNAME=mmmjheng@gmail.com
      - LUNES_PASSWORD=近哈IJR!
      - CHECK_INTERVAL=30
      - MAX_RETRIES=3
      - WS_URL=wss://betadash.lunes.host/api/websocket
    restart: unless-stopped
EOF

# 创建 Dockerfile
echo -e "${BLUE}创建 Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
FROM python:3.13-slim
WORKDIR /app
COPY lunes_login.py /app/
RUN apt-get update && apt-get install -y \
    chromium-driver \
    chromium \
    && rm -rf /var/lib/apt/lists/*
RUN python3.13 -m pip install selenium websocket-client
CMD ["python3.13", "lunes_login.py"]
EOF

# 构建并启动 lunes-monitor
echo -e "${BLUE}构建并启动 lunes-monitor 容器...${NC}"
docker-compose build --no-cache
docker-compose up -d
if [ $? -ne 0 ]; then
    echo -e "${RED}容器启动失败，请检查日志${NC}"
    exit 1
fi
echo -e "${GREEN}lunes-monitor 容器启动成功${NC}"

# 进入 Xray 项目目录
cd "$PROJECT_DIR" || exit 1

# 备份并修改 app.py
if [ -f "app.py" ]; then
    cp app.py app.py.backup
    echo -e "${GREEN}备份 app.py 成功${NC}"
else
    echo -e "${RED}app.py 不存在，退出${NC}"
    exit 1
fi

sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID')/" app.py
sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', '$CFIP')/" app.py
sed -i "s/CFPORT = int(os.environ.get('CFPORT', '[^']*'))/CFPORT = int(os.environ.get('CFPORT', '$CFPORT'))/" app.py
sed -i "s/ARGO_PORT = int(os.environ.get('ARGO_PORT', '[^']*'))/ARGO_PORT = int(os.environ.get('ARGO_PORT', '$ARGO_PORT'))/" app.py
echo -e "${GREEN}配置 UUID、CFIP、CFPORT、ARGO_PORT 成功${NC}"

# 优化 YouTube 分流
echo -e "${BLUE}应用 YouTube 分流优化...${NC}"
cat > youtube_patch.py << 'EOF'
# coding: utf-8
import os

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

old_config = 'config = {"log":{"access":"/dev/null","error":"/dev/null","loglevel":"none"},"inbounds":[{"port":ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":UUID,"flow":"xtls-rprx-vision"}],"decryption":"none","fallbacks":[{"dest":3001},{"path":"/vless-argo","dest":3002},{"path":"/vmess-argo","dest":3003},{"path":"/trojan-argo","dest":3004}]},"streamSettings":{"network":"tcp"}},{"port":3001,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID}],"decryption":"none"},"streamSettings":{"network":"ws","security":"none"}},{"port":3002,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID,"level":0}],"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vless-argo"}}},{"port":3003,"listen":"127.0.0.1","protocol":"vmess","settings":{"clients":[{"id":UUID,"alterId":0}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/vmess-argo"}}},{"port":3004,"listen":"127.0.0.1","protocol":"trojan","settings":{"clients":[{"password":UUID}]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/trojan-argo"}}}],"outbounds":[{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]}'

new_config = '''config = {
    "log": {"access": "/dev/null", "error": "/dev/null", "loglevel": "none"},
    "inbounds": [
        {
            "port": ARGO_PORT,
            "protocol": "vless",
            "settings": {
                "clients": [{"id": UUID, "flow": "xtls-rprx-vision"}],
                "decryption": "none",
                "fallbacks": [
                    {"dest": 3001},
                    {"path": "/vless-argo?ed=2560", "dest": 3002},
                    {"path": "/vmess-argo?ed=2560", "dest": 3003},
                    {"path": "/trojan-argo?ed=2560", "dest": 3004}
                ]
            },
            "streamSettings": {"network": "tcp"}
        },
        {
            "port": 3001,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {"clients": [{"id": UUID}], "decryption": "none"},
            "streamSettings": {"network": "ws", "security": "none"}
        },
        {
            "port": 3002,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {"clients": [{"id": UUID, "level": 0}], "decryption": "none"},
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {"path": "/vless-argo?ed=2560"}
            },
            "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
        },
        {
            "port": 3003,
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "settings": {"clients": [{"id": UUID, "alterId": 0}]},
            "streamSettings": {
                "network": "ws",
                "wsSettings": {"path": "/vmess-argo?ed=2560"}
            },
            "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
        },
        {
            "port": 3004,
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "settings": {"clients": [{"password": UUID}]},
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {"path": "/trojan-argo?ed=2560"}
            },
            "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
        }
    ],
    "outbounds": [
        {"protocol": "freedom", "tag": "direct"},
        {"protocol": "freedom", "tag": "youtube"},
        {"protocol": "blackhole", "tag": "block"}
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "domain": [
                    "geosite:youtube",
                    "youtube.com", "youtu.be",
                    "googlevideo.com", "ytimg.com",
                    "gstatic.com", "googleapis.com",
                    "ggpht.com", "googleusercontent.com"
                ],
                "outboundTag": "youtube"
            }
        ]
    }
}'''

content = content.replace(old_config, new_config)

old_generate = '''async def generate_links(argo_domain):'''
new_generate = '''async def generate_links(argo_domain):
    if not argo_domain or argo_domain == "trycloudflare.com":
        argo_domain = "drama-quit-portable-canvas.trycloudflare.com"
        print(f"使用默认 Argo 域名: {argo_domain}")
    meta_info = subprocess.run(['curl', '-s', 'https://speed.cloudflare.com/meta'], capture_output=True, text=True)
    meta_info = meta_info.stdout.split('"')
    ISP = f"{meta_info[25]}-{meta_info[17]}".replace(' ', '_').strip()
    time.sleep(2)
    VMESS = {"v": "2", "ps": f"{NAME}-{ISP}", "add": CFIP, "port": CFPORT, "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "tls", "sni": argo_domain, "fp": "chrome"}
    list_txt = f"""vless://{UUID}@{CFIP}:{CFPORT}?encryption=none&security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}
vmess://{base64.b64encode(json.dumps(VMESS).encode('utf-8')).decode('utf-8')}
trojan://{UUID}@{CFIP}:{CFPORT}?security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}"""
    with open(os.path.join(FILE_PATH, 'list.txt'), 'w', encoding='utf-8') as f: f.write(list_txt)
    sub_txt = base64.b64encode(list_txt.encode('utf-8')).decode('utf-8')
    with open(os.path.join(FILE_PATH, 'sub.txt'), 'w', encoding='utf-8') as f: f.write(sub_txt)
    print(sub_txt)
    print(f"{FILE_PATH}/sub.txt saved successfully")
    return sub_txt'''

content = content.replace(old_generate, new_generate)

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)
EOF

python3.13 youtube_patch.py
rm youtube_patch.py
echo -e "${GREEN}YouTube 分流优化完成${NC}"

# 启动 Xray 服务
echo -e "${BLUE}启动 Xray 服务...${NC}"
pkill -f "python3 app.py" 2>/dev/null
sleep 2
nohup python3.13 app.py > app.log 2>&1 &
APP_PID=$!
sleep 10

if ! ps -p "$APP_PID" > /dev/null; then
    echo -e "${RED}Xray 服务启动失败，检查日志${NC}"
    echo -e "${YELLOW}日志: tail -f $PROJECT_DIR/app.log${NC}"
    exit 1
fi
echo -e "${GREEN}Xray 服务启动成功，PID: $APP_PID${NC}"

# 等待节点生成
echo -e "${BLUE}等待节点信息生成 (最多10分钟)...${NC}"
MAX_WAIT=600
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f "$PROJECT_DIR/.cache/sub.txt" ] || [ -f "$PROJECT_DIR/sub.txt" ]; then
        NODE_INFO=$(cat "$PROJECT_DIR/.cache/sub.txt" 2>/dev/null || cat "$PROJECT_DIR/sub.txt" 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}节点信息生成成功${NC}"
            break
        fi
    fi
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        echo -e "${YELLOW}已等待 $((WAIT_COUNT/60)) 分 $((WAIT_COUNT%60)) 秒...${NC}"
    fi
done

# 输出节点信息
if [ -n "$NODE_INFO" ]; then
    echo -e "${GREEN}=== 节点信息 ===${NC}"
    echo -e "${GREEN}订阅链接:${NC}"
    echo "$NODE_INFO" | base64 -d
    echo -e "${GREEN}订阅 base64:${NC}"
    echo "$NODE_INFO"
    echo -e "${YELLOW}将上述订阅链接添加到客户端测试${NC}"
else
    echo -e "${RED}节点信息生成超时，请检查日志${NC}"
    echo -e "${YELLOW}日志: tail -f $PROJECT_DIR/app.log${NC}"
fi

echo -e "${GREEN}部署完成！${NC}"
