# ZidStore Tunnel

A comprehensive VPN/Tunnel installation script for Ubuntu/Debian servers. This script installs and configures multiple proxy protocols including Xray (VMess, VLESS, Trojan, Shadowsocks), OpenVPN, SlowDNS, WebSocket, BadVPN, UDP Custom, and more.

## Features

- **Xray Core**: VMess, VLESS, Trojan, Shadowsocks with WebSocket + gRPC
- **OpenVPN**: TCP, UDP, and SSL configurations
- **SlowDNS**: DNSTT client/server for DNS tunneling
- **WebSocket Proxy**: Python-based WebSocket proxy
- **BadVPN**: UDP tunneling (ports 7100, 7200, 7300)
- **UDP Custom**: Custom UDP server
- **HAProxy**: Load balancing and SSL termination
- **Nginx**: Reverse proxy with SSL
- **Dropbear**: Lightweight SSH server
- **SSL Certificates**: Automatic Let's Encrypt via acme.sh
- **Cloudflare DNS**: Automatic NS record creation for SlowDNS
- **Systemd Services**: All components managed as services
- **Swap**: Automatic 5GB swap file creation
- **BBR**: TCP BBR congestion control

## Requirements

- Ubuntu 18.04/20.04/22.04/24.04 or Debian 10/11/12
- Root access
- A domain pointing to your VPS IP
- Cloudflare account (for SlowDNS NS records)

## Installation

### One-Line Install (Recommended)
```bash
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/zidstoretunnel/main/zidstoretunnel | sudo bash
```

Or with a domain:
```bash
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/zidstoretunnel/main/zidstoretunnel | sudo bash -s yourdomain.com
```

### Auto-Update
```bash
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/zidstoretunnel/main/zidstoretunnel | sudo bash -s -- --update
```

### Manual Install
```bash
# Download
wget -O zidstoretunnel https://raw.githubusercontent.com/YOUR_USERNAME/zidstoretunnel/main/zidstoretunnel

# Make executable
chmod +x zidstoretunnel

# Run
sudo ./zidstoretunnel
```

## Configuration

The script uses the following default configuration (can be modified in the script):

| Variable | Default | Description |
|----------|---------|-------------|
| `domain_ns` | `dnstt.me` | Domain for SlowDNS NS records |
| `timezone` | `Asia/Jakarta` | Server timezone |
| `cf_id` | Your Cloudflare email | Cloudflare API email |
| `cf_key` | Your Cloudflare API key | Cloudflare Global API Key |
| `swap_size` | `5G` | Swap file size |

## Ports Used

| Service | Ports |
|---------|-------|
| SSH | 22 |
| Dropbear | 143, 109 |
| OpenVPN TCP | 1194 |
| OpenVPN UDP | 2200 |
| OpenVPN SSL | 443 |
| Xray VMess | 80, 443 (WS) |
| Xray VLESS | 80, 443 (WS) |
| Xray Trojan | 80, 443 (WS) |
| Xray Shadowsocks | 80, 443 (WS) |
| HAProxy | 80, 443 |
| Nginx | 80, 443 |
| WebSocket | 80, 443 |
| BadVPN | 7100, 7200, 7300 |
| UDP Custom | 2100 |
| SlowDNS | 5300 (UDP) |
| DNSTT Client | 88 (DoH) |

## Post-Installation

After installation completes, the server will prompt for a reboot. Once rebooted:

1. Access the dashboard via `ft dashboard` command
2. Client configurations available at `http://yourdomain.com/`
3. OpenVPN configs: `client-tcp.ovpn`, `client-udp.ovpn`, `client-ssl.ovpn`

## Management Commands

```bash
# Check service status
systemctl status vmess@config vless@config trojan@config shadowsocks@config
systemctl status haproxy nginx ws udp badvpn dnstt-server dnstt-client

# View logs
journalctl -u vmess@config -f
journalctl -u xray -f

# Restart all services
systemctl restart vmess@config vless@config trojan@config shadowsocks@config haproxy nginx ws udp badvpn dnstt-server dnstt-client
```

## File Structure

```
/etc/xray/           # Xray configurations
/etc/xray/vmess/     # VMess configs
/etc/xray/vless/     # VLESS configs
/etc/xray/trojan/    # Trojan configs
/etc/xray/shadowsocks/ # Shadowsocks configs
/etc/slowdns/        # SlowDNS keys and binaries
/etc/openvpn/        # OpenVPN configs
/etc/haproxy/        # HAProxy config
/etc/nginx/          # Nginx configs
/var/www/html/       # Web files (OpenVPN configs)
/usr/bin/            # Custom binaries
/root/.acme.sh/      # SSL certificates
/root/.bot/          # Telegram bot (if configured)
```

## Security Notes

- The script disables UFW and firewalld, using iptables directly
- Sets `net.ipv4.ip_forward=1` for VPN routing
- Creates 5GB swap file
- Configures daily reboot at 05:00
- Log rotation every 6 hours

## Customization

To customize the installation, edit the variables at the top of `zidstoretunnel.sh`:

```bash
domain_ns="your-ns-domain.com"
timezone="Your/Timezone"
cf_id="your@email.com"
cf_key="your-cloudflare-api-key"
swap_size="5G"
```

## For Developers (Building)

The `zidstoretunnel.sh` source file is proprietary and **not uploaded to GitHub**. Only the encoded `zidstoretunnel` output is committed.

```bash
# 1. Edit the source
nano zidstoretunnel.sh

# 2. Build the encoded version
chmod +x build.sh
./build.sh

# 3. Commit & push only the encoded file
git add zidstoretunnel VERSION CHANGELOG.md
git commit -m "v1.0.1 - description"
git push
```

The build script uses **gzip → base64 → chunked array** encoding with randomized variable names. The output is a self-extracting bash script that runs identically to the source.

## License

This project is proprietary. The source code (`zidstoretunnel.sh`) is not publicly distributed. Only the encoded build output (`zidstoretunnel`) is provided for end-user installation.

© 2024 ZidStore Tunnel. All rights reserved.

## Support

For issues, please check the logs or contact the maintainer.