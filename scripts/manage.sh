#!/bin/bash
# ZidStore Tunnel - Service Management Script
# Usage: ./manage.sh [start|stop|restart|status|logs|enable|disable] [service_name]

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICES=(
    "vmess@config"
    "vless@config"
    "trojan@config"
    "shadowsocks@config"
    "haproxy"
    "nginx"
    "ws"
    "udp"
    "badvpn"
    "dnstt-server"
    "dnstt-client"
    "ssh"
    "dropbear"
    "limitip"
    "limitquota"
    "openvpn"
    "cron"
)

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         ZidStore Tunnel - Service Manager                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_usage() {
    echo "Usage: $0 [command] [service]"
    echo ""
    echo "Commands:"
    echo "  start     - Start service(s)"
    echo "  stop      - Stop service(s)"
    echo "  restart   - Restart service(s)"
    echo "  status    - Show status of service(s)"
    echo "  logs      - Show logs of service(s)"
    echo "  enable    - Enable service(s) at boot"
    echo "  disable   - Disable service(s) at boot"
    echo "  all       - Apply command to all services"
    echo ""
    echo "Services:"
    for svc in "${SERVICES[@]}"; do
        echo "  $svc"
    done
    echo ""
    echo "Examples:"
    echo "  $0 status all"
    echo "  $0 restart vmess@config"
    echo "  $0 logs haproxy"
    echo "  $0 enable all"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

run_command() {
    local cmd=$1
    local svc=$2
    
    case $cmd in
        start)
            systemctl start "$svc"
            echo -e "${GREEN}Started $svc${NC}"
            ;;
        stop)
            systemctl stop "$svc"
            echo -e "${YELLOW}Stopped $svc${NC}"
            ;;
        restart)
            systemctl restart "$svc"
            echo -e "${GREEN}Restarted $svc${NC}"
            ;;
        status)
            systemctl status "$svc" --no-pager
            ;;
        logs)
            journalctl -u "$svc" -f --no-pager
            ;;
        enable)
            systemctl enable "$svc"
            echo -e "${GREEN}Enabled $svc${NC}"
            ;;
        disable)
            systemctl disable "$svc"
            echo -e "${YELLOW}Disabled $svc${NC}"
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            print_usage
            exit 1
            ;;
    esac
}

main() {
    check_root
    
    if [[ $# -lt 1 ]]; then
        print_header
        print_usage
        exit 1
    fi
    
    local cmd=$1
    local target=${2:-all}
    
    print_header
    
    if [[ "$target" == "all" ]]; then
        echo -e "${BLUE}Applying '$cmd' to all services...${NC}"
        echo ""
        for svc in "${SERVICES[@]}"; do
            run_command "$cmd" "$svc"
        done
    else
        # Check if service is in our list
        local found=false
        for svc in "${SERVICES[@]}"; do
            if [[ "$svc" == "$target" ]]; then
                found=true
                break
            fi
        done
        
        if [[ "$found" == false ]]; then
            echo -e "${YELLOW}Warning: '$target' is not in the known services list${NC}"
            echo -e "${YELLOW}Proceeding anyway...${NC}"
            echo ""
        fi
        
        run_command "$cmd" "$target"
    fi
}

main "$@"