#!/bin/bash
# ZidStore Tunnel - Structure Test Script
# Verifies that all required files and directories exist

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing ZidStore Tunnel project structure...${NC}"
echo ""

# Required files
FILES=(
    "zidstoretunnel.sh"
    "install.sh"
    "config.example.sh"
    "README.md"
    "LICENSE"
    "CHANGELOG.md"
    "VERSION"
    ".gitignore"
    "scripts/manage.sh"
)

# Required directories
DIRS=(
    "config"
    "config/xray"
    "config/nginx"
    "config/haproxy"
    "systemd"
    "scripts"
)

# Config files
CONFIG_FILES=(
    "config/xray/vmess.json"
    "config/xray/vless.json"
    "config/xray/trojan.json"
    "config/xray/shadowsocks.json"
    "config/udp-config.json"
    "config/nginx/nginx.conf"
    "config/nginx/xray.conf"
    "config/haproxy/haproxy.cfg"
)

# Systemd service files
SERVICE_FILES=(
    "systemd/vmess@config.service"
    "systemd/vless@config.service"
    "systemd/trojan@config.service"
    "systemd/shadowsocks@config.service"
    "systemd/ws.service"
    "systemd/udp.service"
    "systemd/badvpn.service"
    "systemd/dnstt-server.service"
    "systemd/dnstt-client.service"
)

ALL_OK=true

check_files() {
    local label=$1
    shift
    local files=("$@")
    
    echo -e "${BLUE}Checking $label...${NC}"
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "  ${GREEN}✓${NC} $file"
        else
            echo -e "  ${RED}✗${NC} $file (MISSING)"
            ALL_OK=false
        fi
    done
    echo ""
}

check_dirs() {
    local label=$1
    shift
    local dirs=("$@")
    
    echo -e "${BLUE}Checking $label...${NC}"
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo -e "  ${GREEN}✓${NC} $dir/"
        else
            echo -e "  ${RED}✗${NC} $dir/ (MISSING)"
            ALL_OK=false
        fi
    done
    echo ""
}

check_dirs "Directories" "${DIRS[@]}"
check_files "Main Files" "${FILES[@]}"
check_files "Config Files" "${CONFIG_FILES[@]}"
check_files "Systemd Service Files" "${SERVICE_FILES[@]}"

# Check main script is executable
if [[ -x "zidstoretunnel.sh" ]]; then
    echo -e "  ${GREEN}✓${NC} zidstoretunnel.sh is executable"
else
    echo -e "  ${YELLOW}!${NC} zidstoretunnel.sh is not executable (run: chmod +x zidstoretunnel.sh)"
fi

if [[ -x "install.sh" ]]; then
    echo -e "  ${GREEN}✓${NC} install.sh is executable"
else
    echo -e "  ${YELLOW}!${NC} install.sh is not executable (run: chmod +x install.sh)"
fi

if [[ -x "scripts/manage.sh" ]]; then
    echo -e "  ${GREEN}✓${NC} scripts/manage.sh is executable"
else
    echo -e "  ${YELLOW}!${NC} scripts/manage.sh is not executable (run: chmod +x scripts/manage.sh)"
fi

echo ""
if [[ "$ALL_OK" == true ]]; then
    echo -e "${GREEN}✓ All checks passed! Project structure is complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some files are missing. Please check the output above.${NC}"
    exit 1
fi