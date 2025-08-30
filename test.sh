#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NODE_INFO_FILE="$HOME/.xray_nodes_info"
PROJECT_DIR_NAME="python-xray-argo"

# If -v parameter is used, directly view node information
if [ "$1" = "-v" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}                      Node Information                      ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
    else
        echo -e "${RED}Node information file not found${NC}"
        echo -e "${YELLOW}Please run the deployment script first to generate node information${NC}"
    fi
    exit 0
fi

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}

clear

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Python Xray Argo One-Click Deployment Script   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}Based on project: ${YELLOW}https://github.com/eooce/python-xray-argo${NC}"
echo -e "${BLUE}Script repository: ${YELLOW}https://github.com/byJoey/free-vps-py${NC}"
echo -e "${BLUE}TG discussion group: ${YELLOW}https://t.me/+ft-zI76oovgwNmRh${NC}"
echo -e "${RED}Script author's YouTube: ${YELLOW}https://www.youtube.com/@joeyblog${RED}"
echo
echo -e "${GREEN}This script is based on the Python Xray Argo project by eooce${NC}"
echo -e "${GREEN}It offers quick and full configuration modes to simplify deployment${NC}"
echo -e "${GREEN}Supports automatic UUID generation, background execution, and node information output${NC}"
echo -e "${GREEN}Includes YouTube traffic splitting optimization by default, and interactive node information viewing${NC}"
echo

echo -e "${YELLOW}Please select an option:${NC}"
echo -e "${BLUE}1) Quick Mode - Modify UUID and start${NC}"
echo -e "${BLUE}2) Full Mode - Configure all options in detail${NC}"
echo -e "${BLUE}3) View Node Information - Display saved node information${NC}"
echo -e "${BLUE}4) Check Keep-Alive Status - Check Hugging Face API keep-alive status${NC}"
echo
read -p "Enter your choice (1/2/3/4): " MODE_CHOICE

if [ "$MODE_CHOICE" = "3" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}                      Node Information                      ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
        echo -e "${YELLOW}Hint: To redeploy, rerun the script and choose mode 1 or 2${NC}"
    else
        echo
        echo -e "${RED}Node information file not found${NC}"
        echo -e "${YELLOW}Please run the deployment script first to generate node information${NC}"
        echo
        echo -e "${BLUE}Start deployment now? (y/n)${NC}"
        read -p "> " START_DEPLOY
        if [ "$START_DEPLOY" = "y" ] || [ "$START_DEPLOY" = "Y" ]; then
            echo -e "${YELLOW}Please choose a deployment mode:${NC}"
            echo -e "${BLUE}1) Quick Mode${NC}"
            echo -e "${BLUE}2) Full Mode${NC}"
            read -p "Enter your choice (1/2): " MODE_CHOICE
        else
            echo -e "${GREEN}Exiting script${NC}"
            exit 0
        fi
    fi
    
    if [ "$MODE_CHOICE" != "1" ] && [ "$MODE_CHOICE" != "2" ]; then
        echo -e "${GREEN}Exiting script${NC}"
        exit 0
    fi
fi

if [ "$MODE_CHOICE" = "4" ]; then
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}               Hugging Face API Keep-Alive Status Check              ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    if [ -d "$PROJECT_DIR_NAME" ]; then
        cd "$PROJECT_DIR_NAME"
    fi

    KEEPALIVE_PID=$(pgrep -f "keep_alive_task.sh")

    if [ -n "$KEEPALIVE_PID" ]; then
        echo -e "Service status: ${GREEN}Running${NC}"
        echo -e "Process PID: ${BLUE}$KEEPALIVE_PID${NC}"
        if [ -f "keep_alive_task.sh" ]; then
            REPO_ID=$(grep 'huggingface.co/api/spaces/' keep_alive_task.sh | head -1 | sed -n 's|.*api/spaces/\([^"]*\).*|\1|p')
            echo -e "Target repository: ${YELLOW}$REPO_ID (Type: Space)${NC}"
        fi

        echo -e "\n${YELLOW}--- Last keep-alive status ---${NC}"
        if [ -f "keep_alive_status.log" ]; then
           cat keep_alive_status.log
        else
           echo -e "${YELLOW}Status log not yet generated, please wait a moment (up to 2 minutes) and try again...${NC}"
        fi
    else
        echo -e "Service status: ${RED}Not running${NC}"
        echo -e "${YELLOW}Hint: You may not have deployed the service or set up Hugging Face keep-alive during deployment.${NC}"
    fi
    echo
    exit 0
fi


echo -e "${BLUE}Checking and installing dependencies...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Installing Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}Installing Python dependency: requests...${NC}"
    pip3 install requests
fi

if [ ! -d "$PROJECT_DIR_NAME" ]; then
    echo -e "${BLUE}Downloading the full repository...${NC}"
    if command -v git &> /dev/null; then
        git clone https://github.com/eooce/python-xray-argo.git "$PROJECT_DIR_NAME"
    else
        echo -e "${YELLOW}Git not installed, downloading with wget...${NC}"
        wget -q https://github.com/eooce/python-xray-argo/archive/refs/heads/main.zip -O python-xray-argo.zip
        if command -v unzip &> /dev/null; then
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main "$PROJECT_DIR_NAME"
            rm python-xray-argo.zip
        else
            echo -e "${YELLOW}Installing unzip...${NC}"
            sudo apt-get install -y unzip
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main "$PROJECT_DIR_NAME"
            rm python-xray-argo.zip
        fi
    fi
    
    if [ $? -ne 0 ] || [ ! -d "$PROJECT_DIR_NAME" ]; then
        echo -e "${RED}Download failed, please check your network connection${NC}"
        exit 1
    fi
fi

cd "$PROJECT_DIR_NAME"

echo -e "${GREEN}Dependencies installed!${NC}"
echo

if [ ! -f "app.py" ]; then
    echo -e "${RED}app.py not found!${NC}"
    exit 1
fi

cp app.py app.py.backup
echo -e "${YELLOW}Original file backed up as app.py.backup${NC}"

KEEP_ALIVE_HF="false"
HF_TOKEN=""
HF_REPO_ID=""

configure_hf_keep_alive() {
    echo
    echo -e "${YELLOW}Set up Hugging Face API auto keep-alive? (y/n)${NC}"
    read -p "> " SETUP_KEEP_ALIVE
    if [ "$SETUP_KEEP_ALIVE" = "y" ] || [ "$SETUP_KEEP_ALIVE" = "Y" ]; then
        echo -e "${YELLOW}Please enter your Hugging Face access token (Token):${NC}"
        echo -e "${BLUE}(Token is used for API authentication and will not be visible when typed. Go to https://huggingface.co/settings/tokens to get one. If you need help, watch the video tutorial at https://youtu.be/ZRaUWQMjR_c)${NC}"
        read -sp "Token: " HF_TOKEN_INPUT
        echo
        if [ -z "$HF_TOKEN_INPUT" ]; then
            echo -e "${RED}Error: Token cannot be empty. Keep-alive setup cancelled.${NC}"
            return
        fi

        echo -e "${YELLOW}Please enter the Hugging Face repository ID to access (model or space, e.g., joeyhuangt/aaaa):${NC}"
        read -p "Repo ID: " HF_REPO_ID_INPUT
        if [ -z "$HF_REPO_ID_INPUT" ]; then
            echo -e "${RED}Error: Repository ID cannot be empty. Keep-alive setup cancelled.${NC}"
            return
        fi

        HF_TOKEN="$HF_TOKEN_INPUT"
        HF_REPO_ID="$HF_REPO_ID_INPUT"
        KEEP_ALIVE_HF="true"
        echo -e "${GREEN}Hugging Face API keep-alive set!${NC}"
        echo -e "${GREEN}Target repository: $HF_REPO_ID${NC}"
    fi
}

if [ "$MODE_CHOICE" = "1" ]; then
    echo -e "${BLUE}=== Quick Mode ===${NC}"
    echo
    
    echo -e "${YELLOW}Current UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "Enter a new UUID (leave empty to auto-generate): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}Auto-generated UUID: $UUID_INPUT${NC}"
    fi
    
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID set to: $UUID_INPUT${NC}"
    
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', 'joeyblog.net')/" app.py
    echo -e "${GREEN}Preferred IP automatically set to: joeyblog.net${NC}"
    
    configure_hf_keep_alive
    
    echo -e "${GREEN}YouTube traffic splitting automatically configured${NC}"
    echo
    echo -e "${GREEN}Quick configuration complete! Starting service...${NC}"
    echo
    
else
    echo -e "${BLUE}=== Full Configuration Mode ===${NC}"
    echo
    
    echo -e "${YELLOW}Current UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "Enter a new UUID (leave empty to auto-generate): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}Auto-generated UUID: $UUID_INPUT${NC}"
    fi
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID set to: $UUID_INPUT${NC}"

    echo -e "${YELLOW}Current node name: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)${NC}"
    read -p "Enter node name (leave empty to keep current): " NAME_INPUT
    if [ -n "$NAME_INPUT" ]; then
        sed -i "s/NAME = os.environ.get('NAME', '[^']*')/NAME = os.environ.get('NAME', '$NAME_INPUT')/" app.py
        echo -e "${GREEN}Node name set to: $NAME_INPUT${NC}"
    fi

    echo -e "${YELLOW}Current service port: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)${NC}"
    read -p "Enter service port (leave empty to keep current): " PORT_INPUT
    if [ -n "$PORT_INPUT" ]; then
        sed -i "s/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or [0-9]*)/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or $PORT_INPUT)/" app.py
        echo -e "${GREEN}Port set to: $PORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}Current preferred IP: $(grep "CFIP = " app.py | cut -d"'" -f4)${NC}"
    read -p "Enter preferred IP/domain (leave empty for default joeyblog.net): " CFIP_INPUT
    if [ -z "$CFIP_INPUT" ]; then
        CFIP_INPUT="joeyblog.net"
    fi
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', '$CFIP_INPUT')/" app.py
    echo -e "${GREEN}Preferred IP set to: $CFIP_INPUT${NC}"

    echo -e "${YELLOW}Current preferred port: $(grep "CFPORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "Enter preferred port (leave empty to keep current): " CFPORT_INPUT
    if [ -n "$CFPORT_INPUT" ]; then
        sed -i "s/CFPORT = int(os.environ.get('CFPORT', '[^']*'))/CFPORT = int(os.environ.get('CFPORT', '$CFPORT_INPUT'))/" app.py
        echo -e "${GREEN}Preferred port set to: $CFPORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}Current Argo port: $(grep "ARGO_PORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "Enter Argo port (leave empty to keep current): " ARGO_PORT_INPUT
    if [ -n "$ARGO_PORT_INPUT" ]; then
        sed -i "s/ARGO_PORT = int(os.environ.get('ARGO_PORT', '[^']*'))/ARGO_PORT = int(os.environ.get('ARGO_PORT', '$ARGO_PORT_INPUT'))/" app.py
        echo -e "${GREEN}Argo port set to: $ARGO_PORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}Current subscription path: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)${NC}"
    read -p "Enter subscription path (leave empty to keep current): " SUB_PATH_INPUT
    if [ -n "$SUB_PATH_INPUT" ]; then
        sed -i "s/SUB_PATH = os.environ.get('SUB_PATH', '[^']*')/SUB_PATH = os.environ.get('SUB_PATH', '$SUB_PATH_INPUT')/" app.py
        echo -e "${GREEN}Subscription path set to: $SUB_PATH_INPUT${NC}"
    fi

    echo
    echo -e "${YELLOW}Configure advanced options? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG

    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        echo -e "${YELLOW}Current upload URL: $(grep "UPLOAD_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "Enter upload URL (leave empty to keep current): " UPLOAD_URL_INPUT
        if [ -n "$UPLOAD_URL_INPUT" ]; then
            sed -i "s|UPLOAD_URL = os.environ.get('UPLOAD_URL', '[^']*')|UPLOAD_URL = os.environ.get('UPLOAD_URL', '$UPLOAD_URL_INPUT')|" app.py
            echo -e "${GREEN}Upload URL set${NC}"
        fi

        echo -e "${YELLOW}Current project URL: $(grep "PROJECT_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "Enter project URL (leave empty to keep current): " PROJECT_URL_INPUT
        if [ -n "$PROJECT_URL_INPUT" ]; then
            sed -i "s|PROJECT_URL = os.environ.get('PROJECT_URL', '[^']*')|PROJECT_URL = os.environ.get('PROJECT_URL', '$PROJECT_URL_INPUT')|" app.py
            echo -e "${GREEN}Project URL set${NC}"
        fi

        configure_hf_keep_alive

        echo -e "${YELLOW}Current Nezha server: $(grep "NEZHA_SERVER = " app.py | cut -d"'" -f4)${NC}"
        read -p "Enter Nezha server address (leave empty to keep current): " NEZHA_SERVER_INPUT
        if [ -n "$NEZHA_SERVER_INPUT" ]; then
            sed -i "s|NEZHA_SERVER = os.environ.get('NEZHA_SERVER', '[^']*')|NEZHA_SERVER = os.environ.get('NEZHA_SERVER', '$NEZHA_SERVER_INPUT')|" app.py
            
            echo -e "${YELLOW}Current Nezha port: $(grep "NEZHA_PORT = " app.py | cut -d"'" -f4)${NC}"
            read -p "Enter Nezha port (leave empty for v1): " NEZHA_PORT_INPUT
            if [ -n "$NEZHA_PORT_INPUT" ]; then
                sed -i "s|NEZHA_PORT = os.environ.get('NEZHA_PORT', '[^']*')|NEZHA_PORT = os.environ.get('NEZHA_PORT', '$NEZHA_PORT_INPUT')|" app.py
            fi
            
            echo -e "${YELLOW}Current Nezha key: $(grep "NEZHA_KEY = " app.py | cut -d"'" -f4)${NC}"
            read -p "Enter Nezha key: " NEZHA_KEY_INPUT
            if [ -n "$NEZHA_KEY_INPUT" ]; then
                sed -i "s|NEZHA_KEY = os.environ.get('NEZHA_KEY', '[^']*')|NEZHA_KEY = os.environ.get('NEZHA_KEY', '$NEZHA_KEY_INPUT')|" app.py
            fi
            echo -e "${GREEN}Nezha configuration set${NC}"
        fi

        echo -e "${YELLOW}Current Argo domain: $(grep "ARGO_DOMAIN = " app.py | cut -d"'" -f4)${NC}"
        read -p "Enter Argo fixed tunnel domain (leave empty to keep current): " ARGO_DOMAIN_INPUT
        if [ -n "$ARGO_DOMAIN_INPUT" ]; then
            sed -i "s|ARGO_DOMAIN = os.environ.get('ARGO_DOMAIN', '[^']*')|ARGO_DOMAIN = os.environ.get('ARGO_DOMAIN', '$ARGO_DOMAIN_INPUT')|" app.py
            
            echo -e "${YELLOW}Current Argo key: $(grep "ARGO_AUTH = " app.py | cut -d"'" -f4)${NC}"
            read -p "Enter Argo fixed tunnel key: " ARGO_AUTH_INPUT
            if [ -n "$ARGO_AUTH_INPUT" ]; then
                sed -i "s|ARGO_AUTH = os.environ.get('ARGO_AUTH', '[^']*')|ARGO_AUTH = os.environ.get('ARGO_AUTH', '$ARGO_AUTH_INPUT')|" app.py
            fi
            echo -e "${GREEN}Argo fixed tunnel configuration set${NC}"
        fi

        echo -e "${YELLOW}Current Bot Token: $(grep "BOT_TOKEN = " app.py | cut -d"'" -f4)${NC}"
        read -p "Enter Telegram Bot Token (leave empty to keep current): " BOT_TOKEN_INPUT
        if [ -n "$BOT_TOKEN_INPUT" ]; then
            sed -i "s|BOT_TOKEN = os.environ.get('BOT_TOKEN', '[^']*')|BOT_TOKEN = os.environ.get('BOT_TOKEN', '$BOT_TOKEN_INPUT')|" app.py
            
            echo -e "${YELLOW}Current Chat ID: $(grep "CHAT_ID = " app.py | cut -d"'" -f4)${NC}"
            read -p "Enter Telegram Chat ID: " CHAT_ID_INPUT
            if [ -n "$CHAT_ID_INPUT" ]; then
                sed -i "s|CHAT_ID = os.environ.get('CHAT_ID', '[^']*')|CHAT_ID = os.environ.get('CHAT_ID', '$CHAT_ID_INPUT')|" app.py
            fi
            echo -e "${GREEN}Telegram configuration set${NC}"
        fi
    fi
    
    echo -e "${GREEN}YouTube traffic splitting automatically configured${NC}"

    echo
    echo -e "${GREEN}Full configuration complete!${NC}"
fi

echo -e "${YELLOW}=== Current Configuration Summary ===${NC}"
echo -e "UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)"
echo -e "Node name: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)"
echo -e "Service port: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)"
echo -e "Preferred IP: $(grep "CFIP = " app.py | cut -d"'" -f4)"
echo -e "Preferred port: $(grep "CFPORT = " app.py | cut -d"'" -f4)"
echo -e "Subscription path: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)"
if [ "$KEEP_ALIVE_HF" = "true" ]; then
    echo -e "Keep-alive repository: $HF_REPO_ID"
fi
echo -e "${YELLOW}========================${NC}"
echo

echo -e "${BLUE}Starting service...${NC}"
echo -e "${YELLOW}Current working directory: $(pwd)${NC}"
echo

echo -e "${BLUE}Adding YouTube traffic splitting and port 80 node...${NC}"
cat > youtube_patch.py << 'EOF'
import os, base64, json, subprocess, time

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

old_config = 'config ={"log":{"access":"/dev/null","error":"/dev/null","loglevel":"none",},"inbounds":[{"port":ARGO_PORT ,"protocol":"vless","settings":{"clients":[{"id":UUID ,"flow":"xtls-rprx-vision",},],"decryption":"none","fallbacks":[{"dest":3001 },{"path":"/vless-argo","dest":3002 },{"path":"/vmess-argo","dest":3003 },{"path":"/trojan-argo","dest":3004 },],},"streamSettings":{"network":"tcp",},},{"port":3001 ,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID },],"decryption":"none"},"streamSettings":{"network":"ws","security":"none"}},{"port":3002 ,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID ,"level":0 }],"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vless-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},{"port":3003 ,"listen":"127.0.0.1","protocol":"vmess","settings":{"clients":[{"id":UUID ,"alterId":0 }]},"streamSettings":{"network":"ws","wsSettings":{"path":"/vmess-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},{"port":3004 ,"listen":"127.0.0.1","protocol":"trojan","settings":{"clients":[{"password":UUID },]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/trojan-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},],"outbounds":[{"protocol":"freedom","tag": "direct" },{"protocol":"blackhole","tag":"block"}]}'

new_config = '''config = {
        "log": {
            "access": "/dev/null",
            "error": "/dev/null",
            "loglevel": "none"
        },
        "inbounds": [
            {
                "port": ARGO_PORT,
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID, "flow": "xtls-rprx-vision"}],
                    "decryption": "none",
                    "fallbacks": [
                        {"dest": 3001},
                        {"path": "/vless-argo", "dest": 3002},
                        {"path": "/vmess-argo", "dest": 3003},
                        {"path": "/trojan-argo", "dest": 3004}
                    ]
                },
                "streamSettings": {"network": "tcp"}
            },
            {
                "port": 3001,
                "listen": "127.0.0.1",
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID}],
                    "decryption": "none"
                },
                "streamSettings": {"network": "ws", "security": "none"}
            },
            {
                "port": 3002,
                "listen": "127.0.0.1",
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID, "level": 0}],
                    "decryption": "none"
                },
                "streamSettings": {
                    "network": "ws",
                    "security": "none",
                    "wsSettings": {"path": "/vless-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            },
            {
                "port": 3003,
                "listen": "127.0.0.1",
                "protocol": "vmess",
                "settings": {
                    "clients": [{"id": UUID, "alterId": 0}]
                },
                "streamSettings": {
                    "network": "ws",
                    "wsSettings": {"path": "/vmess-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            },
            {
                "port": 3004,
                "listen": "127.0.0.1",
                "protocol": "trojan",
                "settings": {
                    "clients": [{"password": UUID}]
                },
                "streamSettings": {
                    "network": "ws",
                    "security": "none",
                    "wsSettings": {"path": "/trojan-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            }
        ],
        "outbounds": [
            {"protocol": "freedom", "tag": "direct"},
            {
                "protocol": "vmess",
                "tag": "youtube",
                "settings": {
                    "vnext": [{
                        "address": "172.233.171.224",
                        "port": 16416,
                        "users": [{
                            "id": "8c1b9bea-cb51-43bb-a65c-0af31bbbf145",
                            "alterId": 0
                        }]
                    }]
                },
                "streamSettings": {"network": "tcp"}
            },
            {"protocol": "blackhole", "tag": "block"}
        ],
        "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                {
                    "type": "field",
                    "outboundTag": "youtube",
                    "domain": [
                        "youtube.com", "youtu.be", "googlevideo.com", "ytimg.com", "ggpht.com", "youtubei.googleapis.com", 
                        "yt3.ggpht.com", "i.ytimg.com", "yt-live-chat.google.com"
                    ]
                }
            ]
        }
    }'''
content = content.replace(old_config, new_config)

old_generate_function = '''# Generate links and subscription content
async def generate_links(argo_domain):
    meta_info = subprocess.run(['curl', '-s', 'https://speed.cloudflare.com/meta'], capture_output=True, text=True)
    meta_info = meta_info.stdout.split('"')
    ISP = f"{meta_info[25]}-{meta_info[17]}".replace(' ', '_').strip()

    time.sleep(2)
    VMESS = {"v": "2", "ps": f"{NAME}-{ISP}", "add": CFIP, "port": CFPORT, "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "tls", "sni": argo_domain, "alpn": "", "fp": "chrome"}
 
    list_txt = f"""
vless://{UUID}@{CFIP}:{CFPORT}?encryption=none&security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}
  
vmess://{ base64.b64encode(json.dumps(VMESS).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:{CFPORT}?security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}
    """
    
    with open(os.path.join(FILE_PATH, 'list.txt'), 'w', encoding='utf-8') as list_file:
        list_file.write(list_txt)

    sub_txt = base64.b64encode(list_txt.encode('utf-8')).decode('utf-8')
    with open(os.path.join(FILE_PATH, 'sub.txt'), 'w', encoding='utf-8') as sub_file:
        sub_file.write(sub_txt)
        
    print(sub_txt)
    
    print(f"{FILE_PATH}/sub.txt saved successfully")
    
    send_telegram()
    upload_nodes()
 
    return sub_txt'''

new_generate_function = '''# Generate links and subscription content
async def generate_links(argo_domain):
    meta_info = subprocess.run(['curl', '-s', 'https://speed.cloudflare.com/meta'], capture_output=True, text=True)
    meta_info = meta_info.stdout.split('"')
    ISP = f"{meta_info[25]}-{meta_info[17]}".replace(' ', '_').strip()

    time.sleep(2)
    
    VMESS_TLS = {"v": "2", "ps": f"{NAME}-{ISP}-TLS", "add": CFIP, "port": CFPORT, "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "tls", "sni": argo_domain, "alpn": "", "fp": "chrome"}
    
    VMESS_80 = {"v": "2", "ps": f"{NAME}-{ISP}-80", "add": CFIP, "port": "80", "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "", "sni": "", "alpn": "", "fp": ""}
 
    list_txt = f"""
vless://{UUID}@{CFIP}:{CFPORT}?encryption=none&security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}-TLS
  
vmess://{ base64.b64encode(json.dumps(VMESS_TLS).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:{CFPORT}?security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}-TLS

vless://{UUID}@{CFIP}:80?encryption=none&security=none&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}-80

vmess://{ base64.b64encode(json.dumps(VMESS_80).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:80?security=none&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}-80
    """
    
    with open(os.path.join(FILE_PATH, 'list.txt'), 'w', encoding='utf-8') as list_file:
        list_file.write(list_txt)

    sub_txt = base64.b64encode(list_txt.encode('utf-8')).decode('utf-8')
    with open(os.path.join(FILE_PATH, 'sub.txt'), 'w', encoding='utf-8') as sub_file:
        sub_file.write(sub_txt)
        
    print(sub_txt)
    
    print(f"{FILE_PATH}/sub.txt saved successfully")
    
    send_telegram()
    upload_nodes()
 
    return sub_txt'''

content = content.replace(old_generate_function, new_generate_function)

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("YouTube traffic splitting and port 80 node added successfully")
EOF

python3 youtube_patch.py
rm youtube_patch.py

echo -e "${GREEN}YouTube traffic splitting and port 80 node integrated${NC}"

pkill -f "python3 app.py" > /dev/null 2>&1
sleep 2

python3 app.py > app.log 2>&1 &
APP_PID=$!

if [ -z "$APP_PID" ] || [ "$APP_PID" -eq 0 ]; then
    echo -e "${RED}Failed to get process PID, trying to start directly${NC}"
    nohup python3 app.py > app.log 2>&1 &
    sleep 2
    APP_PID=$(pgrep -f "python3 app.py" | head -1)
    if [ -z "$APP_PID" ]; then
        echo -e "${RED}Service failed to start, please check your Python environment${NC}"
        echo -e "${YELLOW}View logs: tail -f app.log${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Service started in the background, PID: $APP_PID${NC}"
echo -e "${YELLOW}Log file: $(pwd)/app.log${NC}"

KEEPALIVE_PID=""
if [ "$KEEP_ALIVE_HF" = "true" ]; then
    echo -e "${BLUE}Creating and starting Hugging Face API keep-alive task...${NC}"
    echo "#!/bin/bash" > keep_alive_task.sh
    echo "while true; do" >> keep_alive_task.sh
    echo "    status_code=\$(curl -s -o /dev/null -w \"%{http_code}\" --header \"Authorization: Bearer $HF_TOKEN\" \"https://huggingface.co/api/spaces/$HF_REPO_ID\")" >> keep_alive_task.sh
    echo "    if [ \"\$status_code\" -eq 200 ]; then" >> keep_alive_task.sh
    echo "        echo \"Hugging Face API keep-alive successful (Space: $HF_REPO_ID, status code: 200) - \$(date '+%Y-%m-%d %H:%M:%S')\" > keep_alive_status.log" >> keep_alive_task.sh
    echo "    else" >> keep_alive_task.sh
    echo "        status_code_model=\$(curl -s -o /dev/null -w \"%{http_code}\" --header \"Authorization: Bearer $HF_TOKEN\" \"https://huggingface.co/api/models/$HF_REPO_ID\")" >> keep_alive_task.sh
    echo "        if [ \"\$status_code_model\" -eq 200 ]; then" >> keep_alive_task.sh
    echo "            echo \"Hugging Face API keep-alive successful (Model: $HF_REPO_ID, status code: 200) - \$(date '+%Y-%m-%d %H:%M:%S')\" > keep_alive_status.log" >> keep_alive_task.sh
    echo "        else" >> keep_alive_task.sh
    echo "            echo \"Hugging Face API keep-alive failed (Repository: $HF_REPO_ID, Space API status: \$status_code, Model API status: \$status_code_model) - \$(date '+%Y-%m-%d %H:%M:%S')\" > keep_alive_status.log" >> keep_alive_task.sh
    echo "        fi" >> keep_alive_task.sh
    echo "    fi" >> keep_alive_task.sh
    echo "    sleep 120" >> keep_alive_task.sh
    echo "done" >> keep_alive_task.sh
    chmod +x keep_alive_task.sh
    
    nohup ./keep_alive_task.sh >/dev/null 2>&1 &
    KEEPALIVE_PID=$!
    echo -e "${GREEN}Hugging Face API keep-alive task started (PID: $KEEPALIVE_PID).${NC}"
fi


echo -e "${BLUE}Waiting for service to start...${NC}"
sleep 8

if ! ps -p "$APP_PID" > /dev/null 2>&1; then
    echo -e "${RED}Service failed to start, please check logs${NC}"
    echo -e "${YELLOW}View logs: tail -f app.log${NC}"
    echo -e "${YELLOW}Check for port usage: netstat -tlnp | grep :3000${NC}"
    exit 1
fi

echo -e "${GREEN}Service running normally${NC}"

SERVICE_PORT=$(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)
CURRENT_UUID=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
SUB_PATH_VALUE=$(grep "SUB_PATH = " app.py | cut -d"'" -f4)

echo -e "${BLUE}Waiting for node information to generate...${NC}"
echo -e "${YELLOW}Waiting for Argo tunnel to establish and nodes to generate, please be patient...${NC}"

MAX_WAIT=600
WAIT_COUNT=0
NODE_INFO=""

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f ".cache/sub.txt" ]; then
        NODE_INFO=$(cat .cache/sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}Node information generated!${NC}"
            break
        fi
    elif [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}Node information generated!${NC}"
            break
        fi
    fi
    
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        MINUTES=$((WAIT_COUNT / 60))
        SECONDS=$((WAIT_COUNT % 60))
        echo -e "${YELLOW}Waited ${MINUTES}m${SECONDS}s, continuing to wait for node generation...${NC}"
        echo -e "${BLUE}Hint: Argo tunnel establishment takes time, please continue to wait${NC}"
    fi
    
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
done

if [ -z "$NODE_INFO" ]; then
    echo -e "${RED}Timeout! Node information not generated within 10 minutes${NC}"
    echo -e "${YELLOW}Possible reasons:${NC}"
    echo -e "1. Network connection issues"
    echo -e "2. Argo tunnel failed to establish"
    echo -e "3. Service configuration error"
    echo
    echo -e "${BLUE}Recommended actions:${NC}"
    echo -e "1. View logs: ${YELLOW}tail -f $(pwd)/app.log${NC}"
    echo -e "2. Check service: ${YELLOW}ps aux | grep python3${NC}"
    echo -e "3. Rerun the script"
    echo
    echo -e "${YELLOW}Service information:${NC}"
    echo -e "Process PID: ${BLUE}$APP_PID${NC}"
    echo -e "Service port: ${BLUE}$SERVICE_PORT${NC}"
    echo -e "Log file: ${YELLOW}$(pwd)/app.log${NC}"
    exit 1
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}                      Deployment Complete!                      ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${YELLOW}=== Service Information ===${NC}"
echo -e "Service status: ${GREEN}Running${NC}"
echo -e "Main service PID: ${BLUE}$APP_PID${NC}"
if [ -n "$KEEPALIVE_PID" ]; then
    echo -e "Keep-alive service PID: ${BLUE}$KEEPALIVE_PID${NC}"
fi
echo -e "Service port: ${BLUE}$SERVICE_PORT${NC}"
echo -e "UUID: ${BLUE}$CURRENT_UUID${NC}"
echo -e "Subscription path: ${BLUE}/$SUB_PATH_VALUE${NC}"
echo

echo -e "${YELLOW}=== Access Addresses ===${NC}"
if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "Failed to get")
    if [ "$PUBLIC_IP" != "Failed to get" ]; then
        echo -e "Subscription address: ${GREEN}http://$PUBLIC_IP:$SERVICE_PORT/$SUB_PATH_VALUE${NC}"
        echo -e "Admin panel: ${GREEN}http://$PUBLIC_IP:$SERVICE_PORT${NC}"
    fi
fi
echo -e "Local subscription: ${GREEN}http://localhost:$SERVICE_PORT/$SUB_PATH_VALUE${NC}"
echo -e "Local panel: ${GREEN}http://localhost:$SERVICE_PORT${NC}"
echo

echo -e "${YELLOW}=== Node Information ===${NC}"
DECODED_NODES=$(echo "$NODE_INFO" | base64 -d 2>/dev/null || echo "$NODE_INFO")

echo -e "${GREEN}Node configuration:${NC}"
echo "$DECODED_NODES"
echo

echo -e "${GREEN}Subscription link:${NC}"
echo "$NODE_INFO"
echo

SAVE_INFO="========================================
                      Saved Node Information                      
========================================

Deployment time: $(date)
UUID: $CURRENT_UUID
Service port: $SERVICE_PORT
Subscription path: /$SUB_PATH_VALUE

=== Access Addresses ==="

if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "Failed to get")
    if [ "$PUBLIC_IP" != "Failed to get" ]; then
        SAVE_INFO="${SAVE_INFO}
Subscription address: http://$PUBLIC_IP:$SERVICE_PORT/$SUB_PATH_VALUE
Admin panel: http://$PUBLIC_IP:$SERVICE_PORT"
    fi
fi

SAVE_INFO="${SAVE_INFO}
Local subscription: http://localhost:$SERVICE_PORT/$SUB_PATH_VALUE
Local panel: http://localhost:$SERVICE_PORT

=== Node Information ===
$DECODED_NODES

=== Subscription Link ===
$NODE_INFO

=== Management Commands ===
View logs: tail -f $(pwd)/app.log
Stop main service: kill $APP_PID
Restart main service: kill $APP_PID && nohup python3 app.py > app.log 2>&1 &
Check processes: ps aux | grep app.py"

if [ "$KEEP_ALIVE_HF" = "true" ]; then
    SAVE_INFO="${SAVE_INFO}
Stop keep-alive service: pkill -f keep_alive_task.sh && rm keep_alive_task.sh keep_alive_status.log"
fi

SAVE_INFO="${SAVE_INFO}

=== Traffic Splitting Info ===
- YouTube traffic splitting optimization is integrated into the xray configuration
- YouTube-related domains are automatically routed through a dedicated line
- No additional configuration is needed, transparent splitting"

echo "$SAVE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}Node information saved to $NODE_INFO_FILE${NC}"
echo -e "${YELLOW}Use option 3 or run with -v to view node information anytime${NC}"

echo -e "${YELLOW}=== Important Notes ===${NC}"
echo -e "${GREEN}Deployment complete, node information generated successfully${NC}"
echo -e "${GREEN}You can now add the subscription address to your client${NC}"
echo -e "${GREEN}YouTube traffic splitting is integrated into the xray configuration, no extra setup required${NC}"
echo -e "${GREEN}The service will continue to run in the background${NC}"
echo

echo -e "${GREEN}Deployment finished! Thank you for using!${NC}"

exit 0
