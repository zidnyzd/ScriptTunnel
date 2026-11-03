# 01 Iktisar

## Apa Itu ZidStore Tunnel

ZidStore Tunnel adalah proyek perangkat lunak open-source berbasis skrip Bash yang mendistribusikan server VPN multi-protokol dalam satu deploy. Proyek ini menggabungkan empat lapisan utama: lapisan ingress (HAProxy, Nginx), lapisan proxy aplikasi (Xray Core, OpenVPN, SlowDNS, WebSocket, BadVPN, UDP Custom), lapisan manajemen layanan (unit systemd, scripts/manage.sh), dan lapisan keamanan (validasi lisensi berbasis IP, isolasi konfigurasi, iptables, sysctl).

Skrip utama berada di `zidstoretunnel.sh`, builder di `build.sh`, wrapper bootstrap di `install.sh`, dan script verifikasi struktur di `test_structure.sh`.

## Tujuan

Tujuan proyek ini adalah menjawab masalah deployment tunnel VPN multi-protokol dengan cara yang terstandar, terotomatisasi, dan reproducible. Instalasi dilakukan oleh satu perintah: `curl -sL https://zds.web.id/?key=YOUR_KEY | sudo bash`. Proyek ini mengorbankan kompleksitas manajemen yang terpisah untuk memberikan satu host yang mengekspos beberapa protokol melalui port yang sama.

## Scope

Scope proyek ini mencakup:

- Instalasi Xray Core dengan inbounds VMess, VLESS, Trojan, dan Shadowsocks.
- Instalasi OpenVPN dengan profil TCP, UDP, dan SSL.
- Instalasi SlowDNS menggunakan DNSTT server dan client.
- Instalasi WebSocket proxy Python `ws.py`.
- Instalasi BadVPN UDPGW pada port 7100, 7200, 7300.
- Instalasi UDP Custom biner pada port 2100.
- Konfigurasi HAProxy untuk SSL termination port 443 dan routing ke backend.
- Konfigurasi Nginx sebagai reverse proxy untuk semua path Xray WebSocket.
- Manajemen unit systemd untuk semua komponen.
- Validasi lisensi berbasis IP.
- Auto-update melalui URL GitHub raw.

## Prinsip Desain

### Modularitas Systemd

Setiap komponen ditempatkan sebagai unit systemd terpisah. VMess, VLESS, Trojan, dan Shadowsocks menggunakan template instance `vmess@config.service`, `vless@config.service`, `trojan@config.service`, `shadowsocks@config.service`. Setiap instance membaca file konfigurasi `config.json` di direktori masing-masing `/etc/xray/vmess`, `/etc/xray/vless`, `/etc/xray/trojan`, `/etc/xray/shadowsocks`.

Contoh di `zidstoretunnel.sh:1061`:

```
create_service "vmess" "ZidStore Tunnel Xray Instance" "/usr/local/bin/xray run -config /etc/xray/vmess/%i.json"
```

### Multiplexing HAProxy

HAProxy menerima koneksi port 80 dan 443, menerapkan SSL termination, lalu meneruskan traffic ke backend Nginx atau Xray WebSocket berdasarkan ACL. Konfigurasi `config/haproxy/haproxy.cfg:43` mendefinisikan frontend `https_in` untuk port 443 dengan `crt /etc/haproxy/yha.pem`. `config/haproxy/haproxy.cfg:51` mendefinisikan ACL untuk upgrade WebSocket, `config/haproxy/haproxy.cfg:52-56` mendefinisikan ACL path untuk vmess, vless, trojan, dan shadowsocks, `config/haproxy/haproxy.cfg:59` meneruskan ke backend xray_ws.

### Proteksi Lisensi

Lisensi dicek sebelum apa pun yang dilakukan instalasi. `zidstoretunnel.sh:60-65` memeriksa `INSTALL_KEY`, `zidstoretunnel.sh:68-70` memvalidasi kunci ke `ZIDSTORE_API_URL/api/key?key=INSTALL_KEY`. IP VPS divalidasi melawan daftar yang diberikan oleh API server.

## Apa yang BUKAN Proyek Ini

- Proyek ini tidak menciptakan service berbeda dengan domain terpisah.
- Proyek ini tidak menerapkan penggunaan GPU untuk enkripsi.
- Proyek ini tidak mendukung perutean antar VPC dari implementasi cloud provider.
- Proyek ini tidak menggantikan sistem firewall berbasis bridge atau virtual switch.
- Proyek ini tidak dirancang untuk deploy berlatar belakang multi-tenant dengan isolasi hard terhadap sesi container.

## Prinsip Keamanan

1. Validasi lisensi berbasis IP: kunci instalasi dicek terlebih dahulu terhadap API server, dan IP VPS diverifikasi.
2. Isolasi konfigurasi: setiap protokol memiliki direktori konfigurasi sendiri di `/etc/xray/`.
3. Setidaknya satu jalur manajemen layanan: `systemctl status vmess@config` dan `systemctl restart vmess@config` adalah perintah yang valid.
4. Capability bounding set yang terbatas untuk unit systemd: `CAP_NET_ADMIN`, `CAP_NET_BIND_SERVICE`, dan `CAP_NET_RAW` saja.
5. `NoNewPrivileges=yes` atau `NoNewPrivileges=true` di hampir semua unit systemd.
6. Sertifikat SSL menggunakan Let's Encrypt dengan `acme.sh`.

## Tabel Rujukan Berkas Penting

| Berkas | Baris Penting |
|---|---|
| `zidstoretunnel.sh` | `zidstoretunnel.sh:60-70` validasi key dan IP |
| `zidstoretunnel.sh` | `zidstoretunnel.sh:124-127` input domain |
| `zidstoretunnel.sh` | `zidstoretunnel.sh:130-136` verifikasi DNS A record |
| `zidstoretunnel.sh` | `zidstoretunnel.sh:762-770` konfigurasi sysctl ip_forward |
| `config/haproxy/haproxy.cfg` | `config/haproxy/haproxy.cfg:43-63` frontend SSL termination |
| `config/nginx/xray.conf` | `config/nginx/xray.conf:33-98` location proxy Xray WebSocket |
| `config/xray/vmess.json` | `config/xray/vmess.json:8-28` inbound VMess port 80 |
| `config/xray/vless.json` | `config/xray/vless.json:8-28` inbound VLESS port 80 |
| `config/xray/trojan.json` | `config/xray/trojan.json:8-37` inbound Trojan port 443 |
| `config/xray/shadowsocks.json` | `config/xray/shadowsocks.json:8-39` inbound Shadowsocks port 443 |
| `config/udp-config.json` | `config/udp-config.json:1-7` listener UDP port 2100 |
| `build.sh` | `build.sh:56-59` gzip dan base64 |
| `build.sh` | `build.sh:75-76` chunk size 3072 |
| `scripts/manage.sh` | `scripts/manage.sh:72-109` fungsi run_command untuk systemctl |
| `install.sh` | `install.sh:22-69` bootstrap yang memeriksa root dan domain |
