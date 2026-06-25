#!/bin/bash
# ZidStore Tunnel - Quick Install Wrapper
# This script downloads and runs the main installer with optional configuration

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_URL="https://raw.githubusercontent.com/your-username/zidstoretunnel/main"
SCRIPT_NAME="zidstoretunnel.sh"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           ZidStore Tunnel - Quick Installer                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo -e "${YELLOW}Please run: sudo bash install.sh${NC}"
   exit 1
fi

# Check OS
if [[ ! -f /etc/os-release ]]; then
    echo -e "${RED"${RED}Cannot detect OS. This script supports Ubuntu/Debian only.${NC}"
    exit 1
fi

source /etc/os-release
echo -e "${GREEN}Detected OS: $PRETTY_NAME${NC}"

# Check if config.sh exists
if [[ -f "config.sh" ]]; then
    echo -e "${GREEN}Found config.sh, loading configuration...${NC}"
    source config.sh
else
    echo -e "${YELLOW}No config.sh found. Using defaults or interactive mode.${NC}"
    echo -e "${YELLOW}Copy config.example.sh to config.sh and customize for unattended install.${NC}"
    echo ""
fi

# Download main script if not present
if [[ ! -f "$SCRIPT_NAME" ]]; then
    echo -e "${BLUE}Downloading $SCRIPT_NAME...${NC}"
    if ! wget -q -O "$SCRIPT_NAME" "$REPO_URL/$SCRIPT_NAME"; then
        echo -e "${RED}Failed to download installer. Check REPO_URL in install.sh${NC}"
        exit 1
    fi
    chmod +x "$SCRIPT_NAME"
    echo -e "${GREEN}Downloaded successfully${NC}"
else
    echo -e "${GREEN}$SCRIPT_NAME already exists${NC}"
fi

# Run the installer
echo -e "${BLUE}Starting installation...${NC}"
echo ""

if [[ -n "$DOMAIN" ]]; then
    bash "$SCRIPT_NAME" "$DOMAIN"
else
    bash "$SCRIPT_NAME"
fi