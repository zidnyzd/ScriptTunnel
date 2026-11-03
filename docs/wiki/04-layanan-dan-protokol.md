# 04 Layanan dan Protokol

## Xray Core

Xray Core diinstal melalui skrip resmi XTLS (`zidstoretunnel.sh:790-800`) dengan fallback ke biner tetap `xray.linux.64bit` jika instalasi resmi gagal. Setiap protokol berjalan sebagai instance systemd terpisah yang menunjuk ke direktori konfigurasi masing-masing.

### VMess

`config/xray/vmess.json` mendefinisikan dua inbound:

- Port 80 tanpa TLS, `network: ws`, `path: /vmess` (`config/xray/vmess.json:8-28`).
- Port 443 dengan TLS, `network: ws`, `path: /vmess` (`config/xray/vmess.json:30-60`).

Konfigurasi klien menggunakan UUID `1d1c1d94-6987-4658-a4dc-8821a30fe7e0` dengan `alterId: 0` (`config/xray/vmess.json:14-15`). Skrip instalasi mengganti UUID ini dengan UUID acak yang di-generate dari `/proc/sys/kernel/random/uuid` untuk seluruh protokol (`zidstoretunnel.sh:1186-1189`).

Outbound adalah `freedom` (`config/xray/vmess.json:62-67`).

### VLESS

`config/xray/vless.json` mendefinisikan inbound port 80 tanpa TLS dengan `path: /vless` (`config/xray/vless.json:8-28`) dan inbound port 443 dengan TLS dengan `path: /vless` (`config/xray/vless.json:30-60`). Klien memakai `decryption: none` (`config/xray/vless.json:18`).

### Trojan

`config/xray/trojan.json` mendefinisikan satu inbound port 443 dengan TLS, `network: ws`, `path: /trojan` (`config/xray/trojan.json:8-37`). Password Trojan menggunakan UUID string yang sama (`config/xray/trojan.json:14`).

### Shadowsocks

`config/xray/shadowsocks.json` mendefinisikan satu inbound port 443 dengan TLS, `network: ws`, `path: /shadowsocks` (`config/xray/shadowsocks.json:8-39`). Metode enkripsi adalah `2022-blake3-aes-128-gcm` (`config/xray/shadowsocks.json:14`) dengan `network: tcp,udp` pada level clients (`config/xray/shadowsocks.json:19`).

### Catatan tentang gRPC

README dan CHANGELOG menyebut dukungan gRPC (`README.md:7`, `CHANGELOG.md:13`), namun seluruh konfigurasi Xray yang ada di repo ini hanya menggunakan `network: "ws"` (`config/xray/vmess.json:21`, `config/xray/vless.json:21`, `config/xray/trojan.json:20`, `config/xray/shadowsocks.json:22`). Tidak ada satu pun `grpcSettings` pada konfigurasi di repo. Klaim gRPC berasal dari dokumentasi dan aset server, bukan dari template lokal.

### Path WebSocket

| Protokol | Path | Rujukan |
|---|---|---|
| VMess | `/vmess` | `config/xray/vmess.json:23`, `config/xray/vmess.json:54` |
| VLESS | `/vless` | `config/xray/vless.json:23`, `config/xray/vless.json:54` |
| Trojan | `/trojan` | `config/xray/trojan.json:31` |
| Shadowsocks | `/shadowsocks` | `config/xray/shadowsocks.json:33` |

### Unit systemd

Semua instance Xray berjalan sebagai `User=www-data` dengan `CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE` dan `NoNewPrivileges=yes`:

- `systemd/vmess@config.service:7-10`
- `systemd/vless@config.service:7-10`
- `systemd/trojan@config.service:7-10`
- `systemd/shadowsocks@config.service:7-10`

Template `%i` memungkinkan instance tambahan, misalnya `vmess@config2.service` dengan file `/etc/xray/vmess/config2.json`.

## OpenVPN

### Profil Klien

Tiga profil dibuat oleh skrip di `/etc/openvpn/`:

| Profil | Protokol | Port | Baris |
|---|---|---|---|
| `client-tcp.ovpn` | tcp | 1194 | `zidstoretunnel.sh:848-871` |
| `client-udp.ovpn` | udp | 2200 | `zidstoretunnel.sh:873-896` |
| `client-ssl.ovpn` | tcp | 443 | `zidstoretunnel.sh:898-921` |

Struktur dasar profil TCP (`zidstoretunnel.sh:848-871`):

```
auth-user-pass
client
dev tun
proto tcp
remote $ip 1194
persist-key
persist-tun
pull
resolv-retry infinite
nobind
user nobody
comp-lzo
remote-cert-tls server
verb 3
mute 2
connect-retry 5 5
connect-retry-max 8080
mute-replay-warnings
redirect-gateway def1
script-security 2
cipher none
auth none
```

Perbedaan utama antar profil hanya pada baris `proto` dan `remote`. Profil UDP memakai `proto udp` dan `remote $ip 2200` (`zidstoretunnel.sh:876-877`). Profil SSL memakai `proto tcp` dan `remote $ip 443` (`zidstoretunnel.sh:901-902`).

### Peny-CA dan Distribusi

Fungsi `input_cert_ovpn` (`zidstoretunnel.sh:923-935`) menyisipkan blok `<ca>` dari `/etc/openvpn/ca.crt` ke setiap profil, menyalinnya ke `/var/www/html/`, lalu membuat `allovpn.zip`. Skrip juga menjalankan `sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn` untuk mengaktifkan autostart (`zidstoretunnel.sh:933` dan `zidstoretunnel.sh:945`).

Catatan: profil OpenVPN yang dihasilkan tidak menyertakan `ca` inline di dalam berkas statis `/var/www/html/*.ovpn` sampai fungsi `input_cert_ovpn` berjalan, dan `allovpn.zip` dibuat ulang di `zidstoretunnel.sh:940-942` setelah fungsi tersebut dipanggil.

## SlowDNS (DNSTT)

### Mekanisme

SlowDNS adalah teknik tunneling yang menyamarkan traffic sebagai query DNS. Di ZidStore Tunnel, SlowDNS diimplementasikan dengan DNSTT (DNS tunnel) yang memiliki dua komponen: server dan client.

- Server menerima query DNS masuk di port 5300 UDP dan meneruskan payload ke `127.0.0.1:443` (`systemd/dnstt-server.service:12`).
- Client mengirim query melalui DNS-over-HTTPS (DoH) ke `https://cloudflare-dns.com/dns-query` dan meneruskan ke `127.0.0.1:88` (`systemd/dnstt-client.service:12`).

Kunci privat server berada di `/etc/slowdns/server.key` dan kunci publik di `/etc/slowdns/server.pub` (`systemd/dnstt-server.service:12`, `systemd/dnstt-client.service:12`).

### Konfigurasi DoH

Flag `-doh` pada `dnstt-client` menunjuk ke endpoint DoH Cloudflare (`systemd/dnstt-client.service:12`). Ini memastikan query tunneling tidak terkunci pada port 53 biasa di jaringan lokal.

### Integrasi Cloudflare NS

Domain NS untuk SlowDNS ditentukan oleh variabel `domain_ns` yang didokumentasikan sebagai default `dnstt.me` (`README.md:64`). Domain NS ini harus didelegasikan ke Cloudflare sebagai NS record sehingga query untuk subdomain acak diarahkan ke server SlowDNS. Delegasi Cloudflare API memerlukan `cf_id` dan `cf_key` (`README.md:66-67`).

Variabel `domain_ns` dan `cf_id`/`cf_key` ini tidak didefinisikan di `zidstoretunnel.sh`. Yang ada di skrip hanyalah `timezone` (`zidstoretunnel.sh:155`). Ini berarti konfigurasi SlowDNS pada repo ini berasal dari sisi server API atau aset yang diunduh, bukan dari variabel yang bisa diedit langsung di skrip utama.

### Redirect iptables

Query DNS ke port 53 diarahkan ke port 5300 melalui aturan PREROUTING (`zidstoretunnel.sh:744`):

```
iptables -t nat -A PREROUTING -i $interface -p udp -m udp --dport 53 -j REDIRECT --to-ports 5300
```

### Unit systemd

Kedua unit berjalan sebagai `User=root` dengan `NoNewPrivileges=true`, `CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE`, dan `Restart=on-failure` (`systemd/dnstt-server.service:7-13`, `systemd/dnstt-client.service:7-13`).

## BadVPN UDPGW

BadVPN adalah daemon UDP Generic Wire yang meneruskan paket UDP secara raw untuk aplikasi game, VoIP, dan tunneling. Konfigurasi di repo:

```
ExecStart=/usr/bin/badvpn --listen-addr 127.0.0.1:7100 --listen-addr 127.0.0.1:7200 --listen-addr 127.0.0.1:7300 --max-clients 500
```

Rujukan: `systemd/badvpn.service:9`.

Skrip installer membuat unit dengan tambahan `--max-connections-for-client 64` dan `--client-socket-sndbuf 4194304` (`zidstoretunnel.sh:1171`), sedangkan berkas repo `systemd/badvpn.service:9` tidak memuat kedua flag tersebut. Unit di repo juga tidak menyertakan capability bounding set, sementara unit hasil installer berjalan sebagai root dengan `NoNewPrivileges=true` (`zidstoretunnel.sh:1168-1170`).

Pembuatan unit BadVPN di `zidstoretunnel.sh:1162` ditulis dengan heredoc quoted (`<<'EOF'`), sehingga variabel tidak di-expand, sedangkan unit lain menggunakan heredoc unquoted.

Buffer socket UDP dinaikkan ke 8MB untuk BadVPN (`zidstoretunnel.sh:772-780`), karena BadVPN sering gagal dengan pesan "out of UDP buffer" pada buffer default.

## WebSocket Proxy (ws.py)

Skrip Python `ws.py` diunduh ke `/usr/bin/ws.py` (`zidstoretunnel.sh:638-644`) dan dijalankan sebagai unit `ws.service`:

```
ExecStart=/usr/bin/python3 -O /usr/bin/ws.py
```

Rujukan: `systemd/ws.service:12`, dan identik di `zidstoretunnel.sh:1099`.

Unit ini berjalan sebagai `User=root` dengan `CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE` (`systemd/ws.service:8-11`). Skrip installer membuat direktori `/tmp/ws-ips` sebelum menjalankan service (`zidstoretunnel.sh:1098`), yang dipakai untuk korelasi IP antar koneksi.

Perilaku yang didokumentasikan:

- PROXY protocol v1: header `PROXY TCP4 ...` diteruskan ke backend agar sumber IP asli tidak hilang di balik reverse proxy.
- Deteksi SSH: proxy memeriksa apakah payload merupakan SSH banner dan mengarahkan koneksi ke jalur SSH terpisah.
- Korelasi IP: pemetaan IP klien disimpan per koneksi di `/tmp/ws-ips`.

Nginx sudah menyiapkan location `/ws` dengan header upgrade WebSocket dan timeout 86400 detik (`config/nginx/xray.conf:87-98`).

## UDP Custom

UDP Custom adalah biner tunneling UDP+SOCKS5 yang berjalan di `/usr/bin/udp-custom-linux-amd64` (`zidstoretunnel.sh:720-724`, `zidstoretunnel.sh:175`).

Konfigurasi runtime `/usr/bin/config.json` dibuat oleh skrip (`zidstoretunnel.sh:949-959`) dan identik dengan `config/udp-config.json`:

```
{
  "listen": ":2100",
  "stream_buffer": 33554432,
  "receive_buffer": 83886080,
  "auth": {
    "mode": "passwords"
  }
}
```

Rujukan: `config/udp-config.json:1-8`.

Unit systemd:

```
ExecStart=/usr/bin/udp server -exclude 2200,7300,7200,7100,323,10008,10004 /usr/bin/config.json
```

Rujukan: `systemd/udp.service:8`, identik di `zidstoretunnel.sh:1115`.

Flag `-exclude` mencegah daemon membindingi port yang sudah dipakai layanan lain: 2200 (OpenVPN UDP), 7300/7200/7100 (BadVPN), 323 (chrony NTP), serta 10008 dan 10004.

Unit ini memerlukan `CAP_NET_RAW` selain `CAP_NET_ADMIN` dan `CAP_NET_BIND_SERVICE` (`systemd/udp.service:10-11`), dengan `NoNewPrivileges=true`, `LimitNPROC=10000`, `LimitNOFILE=1000000`, dan `RestartPreventExitStatus=23` (`systemd/udp.service:12-16`).

## HAProxy

HAProxy adalah lapisan pertama yang menerima koneksi publik. Bagian penting:

| Aspek | Nilai | Rujukan |
|---|---|---|
| SSL bind | `bind *:443 ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1` | `config/haproxy/haproxy.cfg:42` |
| HTTP bind | `bind *:80` dengan redirect 301 ke HTTPS | `config/haproxy/haproxy.cfg:64-67` |
| Mode default | `mode tcp` | `config/haproxy/haproxy.cfg:18` |
| Timeout | connect 5000, client 50000, server 50000 | `config/haproxy/haproxy.cfg:21-23` |
| Max connection | `maxconn 4096` | `config/haproxy/haproxy.cfg:10` |
| Cipher TLS | 9 cipher TLS 1.2/1.3 | `config/haproxy/haproxy.cfg:12` |
| Cipher suite | `TLS_AES_128_GCM_SHA256`, `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256` | `config/haproxy/haproxy.cfg:13` |
| Minimum TLS | `ssl-min-ver TLSv1.2 no-tls-tickets` | `config/haproxy/haproxy.cfg:14` |
| Health check | `option httpchk GET /health` | `config/haproxy/haproxy.cfg:72` |
| Backend Xray | `server xray1 127.0.0.1:8080 check inter 2000 rise 2 fall 3` | `config/haproxy/haproxy.cfg:73` |
| Backend Nginx | `server nginx1 127.0.0.1:8081 check inter 2000 rise 2 fall 3` | `config/haproxy/haproxy.cfg:79` |

Frontend TCP opsional untuk VMess, VLESS, Trojan, dan Shadowsocks pada port 8443 sampai 8446 ada dalam bentuk ter-comment (`config/haproxy/haproxy.cfg:81-116`).

## Nginx

Konfigurasi global `config/nginx/nginx.conf`:

- `user www-data` (`config/nginx/nginx.conf:1`)
- `worker_processes auto` (`config/nginx/nginx.conf:2`)
- `worker_connections 768` (`config/nginx/nginx.conf:7`)
- `tcp_nopush on` dan `tcp_nodelay on` (`config/nginx/nginx.conf:13-14`)
- `server_tokens off` (`config/nginx/nginx.conf:17`)
- Gzip level 6 dengan daftar tipe (`config/nginx/nginx.conf:27-31`)
- Rate limit zone `api` pada 10r/s dan `login` pada 5r/m (`config/nginx/nginx.conf:34-35`)
- Upstream `xray_backend` ke `127.0.0.1:8080` dengan `keepalive 32` (`config/nginx/nginx.conf:38-41`)

Konfigurasi site `config/nginx/xray.conf`:

- Redirect HTTP ke HTTPS dengan 301 (`config/nginx/xray.conf:1-7`)
- Listen 443 dengan `ssl http2` (`config/nginx/xray.conf:11-12`)
- Sertifikat dari `/etc/xray/xray.crt` dan `/etc/xray/xray.key` (`config/nginx/xray.conf:16-17`)
- `ssl_protocols TLSv1.2 TLSv1.3` (`config/nginx/xray.conf:18`)
- Header keamanan `X-Frame-Options DENY`, `X-Content-Type-Options nosniff`, `X-XSS-Protection` (`config/nginx/xray.conf:25-27`)
- Root `/var/www/html` (`config/nginx/xray.conf:30`)
- Location `/vmess`, `/vless`, `/trojan`, `/shadowsocks`, `/ws` dengan `proxy_read_timeout 86400` (`config/nginx/xray.conf:34-98`)
- Larangan akses file `.key`, `.crt`, `.pem`, `.conf`, `.log` (`config/nginx/xray.conf:110-112`)

## Dropbear

Dropbear replaces OpenSSH as the lightweight SSH server. Konfigurasi di `/etc/default/dropbear` diunduh dari server API (`zidstoretunnel.sh:594-609`), file init di `/etc/init.d/dropbear`, dan host key DSA di `/etc/dropbear/dropbear_dss_host_key`. Unit dropbear bawaan sistem dihapus (`zidstoretunnel.sh:1078-1080`) dan digantikan oleh SysV init script.

## Manajemen Layanan

`scripts/manage.sh` menyediakan antarmuka terpusat untuk 17 unit (`scripts/manage.sh:14-32`), dengan perintah start, stop, restart, status, logs, enable, disable, dan all (`scripts/manage.sh:76-108`). Fungsi `run_command` memetakan perintah ke `systemctl` (`scripts/manage.sh:72-109`), dan `logs` memakai `journalctl -u <svc> -f` (`scripts/manage.sh:93`).

## Rujukan Berkas:Baris

| Berkas:Baris | Isi |
|---|---|
| `config/xray/vmess.json:14` | UUID klien VMess |
| `config/xray/vmess.json:21` | `network: ws` VMess port 80 |
| `config/xray/vmess.json:44-52` | TLS VMess port 443 |
| `config/xray/vless.json:18` | `decryption: none` |
| `config/xray/trojan.json:14` | Password Trojan |
| `config/xray/shadowsocks.json:14` | Metode `2022-blake3-aes-128-gcm` |
| `zidstoretunnel.sh:1186-1189` | Rotasi UUID semua protokol |
| `zidstoretunnel.sh:848-921` | Pembuatan tiga profil ovpn |
| `zidstoretunnel.sh:923-935` | Fungsi input_cert_ovpn |
| `zidstoretunnel.sh:949-959` | Pembuatan /usr/bin/config.json |
| `zidstoretunnel.sh:1107-1125` | Unit udp.service installer |
| `zidstoretunnel.sh:1161-1179` | Unit badvpn.service installer |
| `zidstoretunnel.sh:1098` | Pembuatan /tmp/ws-ips |
| `config/haproxy/haproxy.cfg:49-57` | ACL dan routing WebSocket |
| `config/nginx/nginx.conf:34-35` | Rate limiting zone |
| `config/nginx/xray.conf:25-27` | Header keamanan |
