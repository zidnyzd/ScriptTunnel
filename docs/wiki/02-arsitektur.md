# 02 Arsitektur

## Diagram Teks Topologi Jaringan

```
Internet
  |
  |:80  (HTTP)
  v
HAProxy (frontend http_in) -----> redirect 301 -> HTTPS
  |
  |:443 (HTTPS)
  v
HAProxy (frontend https_in) -----> SSL termination (yha.pem)
  |
  |--- ACL is_websocket + is_vmess/vless/trojan/shadowsocks/ws
  |    -----> backend xray_ws (127.0.0.1:8080) ---> Xray Core
  |
  |--- default
       -----> backend nginx_http (127.0.0.1:8081) ---> Nginx ---> /var/www/html
```

Alur traffic ingress dimulai dari HAProxy yang bertindak sebagai single point entry port 80 dan 443. Pada port 443, HAProxy melakukan SSL termination menggunakan `/etc/haproxy/yha.pem` yang merupakan gabungan sertifikat dan kunci Xray (`config/haproxy/haproxy.cfg:44`). Berdasarkan ACL header `Upgrade: websocket` dan path yang dimulai `/vmess`, `/vless`, `/trojan`, `/shadowsocks`, atau `/ws`, traffic diteruskan ke backend `xray_ws` di `127.0.0.1:8080` (`config/haproxy/haproxy.cfg:59`). Traffic non-WebSocket (misalnya permintaan statis atau API) diteruskan ke backend `nginx_http` di `127.0.0.1:8081` (`config/haproxy/haproxy.cfg:62`).

Nginx bertindak sebagai reverse proxy yang meneruskan path WebSocket ke `127.0.0.1:8080` (`config/nginx/xray.conf:35`, `config/nginx/xray.conf:48`, `config/nginx/xray.conf:61`, `config/nginx/xray.conf:74`, `config/nginx/xray.conf:88`). Nginx juga menyajikan berkas statis dari `/var/www/html` (`config/nginx/xray.conf:30`).

Xray Core menerima traffic di port 80 dan 443 untuk masing-masing protokol, dengan WebSocket path yang sesuai, dan meneruskan trafik keluar ke `freedom` outbound.

## Multiplexing Port 80 dan 443 via HAProxy -> Nginx -> Xray Core

Lapisan pertama, HAProxy, mengikat port 80 dan 443. `config/haproxy/haproxy.cfg:65-69` mendefinisikan frontend `http_in` yang melakukan redirect 301 ke HTTPS. `config/haproxy/haproxy.cfg:43-63` mendefinisikan frontend `https_in` yang memeriksa ACL `is_websocket` dan ACL path, lalu meneruskan ke `xray_ws` atau `nginx_http`.

Lapisan kedua, Nginx, memiliki konfigurasi site di `/etc/nginx/conf.d/xray.conf` (`zidstoretunnel.sh:1090`). Blok `server` HTTPS di `config/nginx/xray.conf:10-113` menggunakan sertifikat `/etc/xray/xray.crt` dan kunci `/etc/xray/xray.key` (`config/nginx/xray.conf:16-17`), kemudian menetapkan location untuk setiap path protokol.

Lapisan ketiga, Xray Core, berjalan di `127.0.0.1:8080` dengan inbounds terpisah untuk setiap protokol. Setiap instance Xray dijalankan sebagai unit systemd templated:
- `vmess@config.service` menggunakan `/etc/xray/vmess/config.json` (`systemd/vmess@config.service:11`)
- `vless@config.service` menggunakan `/etc/xray/vless/config.json` (`systemd/vless@config.service:11`)
- `trojan@config.service` menggunakan `/etc/xray/trojan/config.json` (`systemd/trojan@config.service:11`)
- `shadowsocks@config.service` menggunakan `/etc/xray/shadowsocks/config.json` (`systemd/shadowsocks@config.service:11`)

## Matriks Alokasi Port

| Layanan | Port | Protokol | Keterangan | Rujukan |
|---|---|---|---|---|
| SSH | 22 | TCP | SSH standar | `zidstoretunnel.sh:1678` |
| Dropbear | 109 | TCP | SSH alternatif | `/etc/default/dropbear` (`zidstoretunnel.sh:979`) |
| Dropbear | 143 | TCP | SSH alternatif | `/etc/default/dropbear` (`zidstoretunnel.sh:979`) |
| Xray VMess WS | 80 | TCP | Inbound VMess tanpa TLS | `config/xray/vmess.json:9` |
| Xray VMess WS | 443 | TCP | Inbound VMess dengan TLS | `config/xray/vmess.json:31` |
| Xray VLESS WS | 80 | TCP | Inbound VLESS tanpa TLS | `config/xray/vless.json:9` |
| Xray VLESS WS | 443 | TCP | Inbound VLESS dengan TLS | `config/xray/vless.json:31` |
| Xray Trojan WS | 443 | TCP | Inbound Trojan dengan TLS | `config/xray/trojan.json:9` |
| Xray Shadowsocks WS | 443 | TCP | Inbound Shadowsocks dengan TLS | `config/xray/shadowsocks.json:9` |
| WebSocket proxy | 80/443 | TCP | Proksi Python ws.py | `systemd/ws.service:12` |
| HAProxy | 80, 443 | TCP | SSL termination dan routing | `config/haproxy/haproxy.cfg:44`, `config/haproxy/haproxy.cfg:66` |
| Nginx | 80, 443 | TCP | Reverse proxy backend xray_ws dan nginx_http | `config/haproxy/haproxy.cfg:75`, `config/haproxy/haproxy.cfg:81` |
| SlowDNS (DNSTT) | 5300 | UDP | Redirect dari PREROUTING | `zidstoretunnel.sh:1163` |
| DNSTT Server | 5300 | UDP | Listener SlowDNS | `systemd/dnstt-server.service:13` |
| BadVPN | 7100 | UDP | Listen address lokal | `systemd/badvpn.service:9` |
| BadVPN | 7200 | UDP | Listen address lokal | `systemd/badvpn.service:9` |
| BadVPN | 7300 | UDP | Listen address lokal | `systemd/badvpn.service:9` |
| UDP Custom | 2100 | TCP/UDP | Listener UDP Custom | `config/udp-config.json:2` |
| Xray Core | 8080 | TCP | Backend WebSocket Xray | `config/haproxy/haproxy.cfg:75` |
| Nginx backend | 8081 | TCP | Backend Nginx HTTP | `config/haproxy/haproxy.cfg:81` |

## Interaksi Antar Modul

1. Client mengirim koneksi ke port 80 atau 443 VPS.
2. HAProxy menerima koneksi, melakukan SSL termination (`config/haproxy/haproxy.cfg:44`), dan memeriksa ACL (`config/haproxy/haproxy.cfg:51-56`).
3. Jika traffic adalah WebSocket dengan path yang cocok, HAProxy meneruskan ke `127.0.0.1:8080` (`config/haproxy/haproxy.cfg:59`). Port 8080 adalah Xray Core yang berjalan sebagai unit `vmess@config.service` (atau vless, trojan, shadowsocks, tergantung path).
4. Jika traffic bukan WebSocket, HAProxy meneruskan ke `127.0.0.1:8081` (`config/haproxy/haproxy.cfg:62`). Port 8081 adalah Nginx yang melayani berkas statis dan reverse proxy tambahan.
5. Nginx meneruskan path WebSocket ke `127.0.0.1:8080` (`config/nginx/xray.conf:35`) dengan header yang diperlukan.
6. Xray Core memverifikasi payload sesuai protokol dan meneruskan trafik keluar ke internet melalui outbound `freedom` (`config/xray/vmess.json:63-66`).
7. SlowDNS menggunakan DNSTT server di port 5300 (`systemd/dnstt-server.service:13`) dengan redirect iptables PREROUTING UDP 53 -> 5300 (`zidstoretunnel.sh:1163`). DNSTT server meneruskan ke `127.0.0.1:22` (SSH). Domain diambil dari `/etc/slowdns/domain` atau env `DNSTT_DOMAIN` (prioritas unit existing > /etc/slowdns/domain > env). Delegasi NS per VPS menggunakan pola `<sub>.zdnstt.web.id` -> `ns-<sub>.zdnstt.web.id`.
8. BadVPN mengikat `127.0.0.1:7100`, `127.0.0.1:7200`, `127.0.0.1:7300` (`systemd/badvpn.service:9`) untuk meneruskan trafik UDP game/VoIP.
9. UDP Custom berjalan di port 2100 (`systemd/udp.service:8`) dengan konfigurasi `/usr/bin/config.json` (`config/udp-config.json:2`).
10. WebSocket proxy Python `ws.py` berjalan sebagai unit `ws.service` (`systemd/ws.service:12`) yang dijalankan sebagai User=root.

## Rujukan Berkas:Baris

| Berkas:Baris | Fungsi |
|---|---|
| `config/haproxy/haproxy.cfg:43` | Frontend `https_in` |
| `config/haproxy/haproxy.cfg:44` | Bind `*:443 ssl crt /etc/haproxy/yha.pem` |
| `config/haproxy/haproxy.cfg:51` | ACL `is_websocket` |
| `config/haproxy/haproxy.cfg:59` | `use_backend xray_ws if is_websocket` |
| `config/haproxy/haproxy.cfg:62` | `default_backend nginx_http` |
| `config/haproxy/haproxy.cfg:75` | Backend `xray_ws` `127.0.0.1:8080` |
| `config/haproxy/haproxy.cfg:81` | Backend `nginx_http` `127.0.0.1:8081` |
| `config/nginx/xray.conf:34` | Location `/vmess` |
| `config/nginx/xray.conf:47` | Location `/vless` |
| `config/nginx/xray.conf:60` | Location `/trojan` |
| `config/nginx/xray.conf:73` | Location `/shadowsocks` |
| `config/nginx/xray.conf:87` | Location `/ws` |
| `config/xray/vmess.json:9` | Port 80 VMess inbound |
| `config/xray/vmess.json:31` | Port 443 VMess inbound |
| `config/xray/vless.json:9` | Port 80 VLESS inbound |
| `config/xray/vless.json:31` | Port 443 VLESS inbound |
| `config/xray/trojan.json:9` | Port 443 Trojan inbound |
| `config/xray/shadowsocks.json:9` | Port 443 Shadowsocks inbound |
| `systemd/vmess@config.service:11` | Unit systemd vmess |
| `systemd/vless@config.service:11` | Unit systemd vless |
| `systemd/trojan@config.service:11` | Unit systemd trojan |
| `systemd/shadowsocks@config.service:11` | Unit systemd shadowsocks |
| `systemd/ws.service:12` | Unit systemd ws |
| `systemd/udp.service:8` | Unit systemd udp |
| `systemd/badvpn.service:9` | Unit systemd badvpn |
| `systemd/dnstt-server.service:7-14` | Unit systemd dnstt-server (user root, capability bounding set, NoNewPrivileges, Restart=on-failure) |
| `systemd/dnstt-client.service:7-14` | Unit systemd dnstt-client (tidak dipasang fase 1; biner uji) |
| `config/udp-config.json:2` | Listener UDP port 2100 |
| `zidstoretunnel.sh:1163` | Iptables PREROUTING UDP 53->5300 |
| `zidstoretunnel.sh:1171-1175` | Iptables POSTROUTING 20.8.0.0/24 MASQUERADE |
| `zidstoretunnel.sh:1665` | Daftar unit systemd yang di-enable dan di-start |
| `zidstoretunnel.sh:1693-1790` | Blok SlowDNS/DNSTT fase 1 (unduh biner, kunci, domain, unit, telemetri) |
| `zidstoretunnel.sh:1828-1830` | Fail-fast kondisional dnstt-server (bila unit ada) |
| `build.sh:57` | Kompresi gzip dan encoding base64 |
