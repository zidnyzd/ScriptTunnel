# Wiki Teknis ZidStore Tunnel

Ringkasan satu paragraf: ZidStore Tunnel adalah skrip instalasi otomatis berbasis Bash untuk membangun server VPN multi-protokol di VPS Linux (Ubuntu/Debian). Skrip ini mengintegrasikan Xray Core (VMess, VLESS, Trojan, Shadowsocks), SlowDNS, WebSocket proxy, BadVPN, dan UDP Custom dalam satu host, dengan HAProxy sebagai titik masuk SSL termination dan Nginx sebagai reverse proxy. Semua komponen dikelola sebagai unit systemd, dan konfigurasi dibangun dari template yang diunduh dari ZidStore API server.

## Peta Navigasi

| File | Topik |
|---|---|
| `README.md` | Halaman ini, peta navigasi dan jalur baca |
| `01-ikhtisar.md` | Definisi, tujuan, scope, prinsip desain, keamanan |
| `02-arsitektur.md` | Topologi jaringan, multiplexing port 80/443, matriks port |
| `03-alur-instalasi.md` | Tahapan instalasi dari curl hingga selesai |
| `04-layanan-dan-protokol.md` | Detail teknis VMess, VLESS, Trojan, Shadowsocks, SlowDNS, BadVPN, UDP Custom, WebSocket |
| `05-build-dan-obfuscasi.md` | Pipeline build, kompresi, chunking, self-extracting loader |
| `06-konfigurasi-dan-jaringan.md` | Variabel default, iptables, tuning kernel, cron |
| `07-jebakan-dan-troubleshooting.md` | Gejala, penyebab teknis, cara mengatasi |
| `08-slowdns-ops.md` | Operasional SlowDNS/DNSTT: aktivasi, kunci, verifikasi, uji |

## Jalur Baca yang Disarankan

1. Pendatang baru: `README.md` -> `01-ikhtisar.md` -> `02-arsitektur.md` -> `03-alur-instalasi.md`.
2. Operator yang ingin memahami protokol: `04-layanan-dan-protokol.md` lalu `06-konfigurasi-dan-jaringan.md`.
3. Pengembang yang ingin membuild release: `05-build-dan-obfuscasi.md`.
4. Troubleshooting: langsung ke `07-jebakan-dan-troubleshooting.md`.

## Tabel "Kalau Mau Tahu X, Buka Halaman Y"

| Kalau Mau Tahu | Buka Halaman |
|---|---|
| Apa itu ZidStore Tunnel dan scope-nya | `01-ikhtisar.md` |
| Topologi jaringan dan alur traffic ingress | `02-arsitektur.md` |
| Matriks alokasi port lengkap | `02-arsitektur.md` |
| Tahapan instalasi dari curl hingga selesai | `03-alur-instalasi.md` |
| Validasi lisensi berbasis IP | `03-alur-instalasi.md` |
| Verifikasi DNS A record domain | `03-alur-instalasi.md` |
| Setup SSL Let's Encrypt via acme.sh | `03-alur-instalasi.md` |
| Konfigurasi VMess/VLESS/Trojan/Shadowsocks | `04-layanan-dan-protokol.md` |
| WebSocket path dan gRPC service name | `04-layanan-dan-protokol.md` |
| SlowDNS DNSTT dan delegasi NS Cloudflare | `04-layanan-dan-protokol.md` |
| Operasional SlowDNS: kunci, verifikasi, uji konektivitas | `08-slowdns-ops.md` |
| BadVPN UDPGW port 7100/7200/7300 | `04-layanan-dan-protokol.md` |
| Skrip Python ws.py dan PROXY protocol v1 | `04-layanan-dan-protokol.md` |
| UDP Custom biner dan config.json | `04-layanan-dan-protokol.md` |
| Pipeline build gzip base64 chunking | `05-build-dan-obfuscasi.md` |
| Cara membuild release baru dan update VERSION | `05-build-dan-obfuscasi.md` |
| Variabel konfigurasi default | `06-konfigurasi-dan-jaringan.md` |
| Aturan iptables NAT PREROUTING dan MASQUERADE | `06-konfigurasi-dan-jaringan.md` |
| Tuning kernel Linux dan TCP BBR | `06-konfigurasi-dan-jaringan.md` |
| Rotasi log dan prompt reboot | `06-konfigurasi-dan-jaringan.md` |
| Validasi lisensi gagal IP mismatch | `07-jebakan-dan-troubleshooting.md` |
| Port 80/443 konflik HAProxy/Nginx | `07-jebakan-dan-troubleshooting.md` |
| Sertifikat SSL acme.sh timeout | `07-jebakan-dan-troubleshooting.md` |
| SlowDNS tidak merespons propagasi NS | `07-jebakan-dan-troubleshooting.md` |
| Dropbear/SSH terkunci firewall | `07-jebakan-dan-troubleshooting.md` |

## Tabel Peta Berkas Inti Project

| Path | Tanggung Jawab Utama |
|---|---|
| `zidstoretunnel.sh` | Skrip instalasi utama VPN multi-protokol |
| `build.sh` | Kompresi gzip, encoding base64, chunking array, loader self-extracting |
| `install.sh` | Bootstrap installer, unduh dan jalankan skrip utama |
| `test_structure.sh` | Verifikasi kelengkapan berkas dan struktur direktori |
| `VERSION` | Versi release (1.0.3) |
| `CHANGELOG.md` | Riwayat perubahan release |
| `README.md` | Dokumentasi pengguna dan panduan instalasi |
| `LICENSE` | Lisensi MIT |
| `config/haproxy/haproxy.cfg` | HAProxy SSL termination dan multiplexing port 443 |
| `config/nginx/nginx.conf` | Konfigurasi global Nginx |
| `config/nginx/xray.conf` | Reverse proxy Nginx untuk path Xray WebSocket |
| `config/xray/vmess.json` | Inbound Xray VMess port 80/443 path /vmess |
| `config/xray/vless.json` | Inbound Xray VLESS port 80/443 path /vless |
| `config/xray/trojan.json` | Inbound Xray Trojan port 443 path /trojan |
| `config/xray/shadowsocks.json` | Inbound Xray Shadowsocks port 443 path /shadowsocks |
| `config/udp-config.json` | Konfigurasi UDP Custom listener port 2100 |
| `scripts/manage.sh` | Manajemen unit systemd (start/stop/restart/status/logs) |
| `systemd/*.service` | Unit systemd untuk badvpn, dnstt, shadowsocks, trojan, udp, vless, vmess, ws |
| `docs/wiki/` | Dokumentasi wiki teknis ini |
