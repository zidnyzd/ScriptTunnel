# Changelog

All notable changes to ZidStore Tunnel will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-XX

### Added
- Initial release of ZidStore Tunnel (renamed from FighterTunnel ub20)
- Complete VPN/Tunnel installation script for Ubuntu/Debian
- Xray Core support: VMess, VLESS, Trojan, Shadowsocks with WebSocket + gRPC
- OpenVPN support: TCP, UDP, SSL configurations
- SlowDNS (DNSTT) client/server for DNS tunneling
- Python WebSocket proxy (ws.py)
- BadVPN UDP tunneling (ports 7100, 7200, 7300)
- UDP Custom server
- HAProxy load balancing with SSL termination
- Nginx reverse proxy with WebSocket support
- Dropbear lightweight SSH server
- Automatic Let's Encrypt SSL certificates via acme.sh
- Cloudflare DNS integration for SlowDNS NS records
- Systemd service management for all components
- Automatic 5GB swap file creation
- TCP BBR congestion control
- Daily reboot scheduling (05:00)
- Log rotation every 6 hours
- Telegram bot integration (optional)
- Service management script (scripts/manage.sh)
- Configuration templates for all services
- Comprehensive documentation (README.md)

### Changed
- Renamed from "FighterTunnel" to "ZidStore Tunnel"
- Updated branding throughout the script
- Organized configuration files into config/ directory
- Separated systemd service files into systemd/ directory
- Added config.example.sh for easy customization
- Added install.sh wrapper for quick installation
- Improved error handling and logging

### Security
- Disabled UFW and firewalld (using iptables directly)
- Enabled IP forwarding for VPN routing
- Configured secure SSL/TLS ciphers
- Set capability bounding for services
- Added NoNewPrivileges for systemd services

## [Unreleased]

### Planned
- Web-based management dashboard
- Multi-user support with quota management
- Prometheus/Grafana monitoring integration
- Docker deployment support
- Ansible playbook for automated deployment
- IPv6 support
- More protocol options (Hysteria, TUIC, etc.)