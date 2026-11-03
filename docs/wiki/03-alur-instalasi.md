# 03 Alur Instalasi

## Tahap 1: Argument Parsing (--key) dan Verifikasi Lisensi IP

Skrip utama `zidstoretunnel.sh` dimulai dengan parsing argumen (`zidstoretunnel.sh:18-87`). Argumen `--key=VALUE` atau `--key VALUE` disimpan ke variabel `INSTALL_KEY`. Jika `INSTALL_KEY` kosong, skrip keluar dengan pesan error (`zidstoretunnel.sh:265-295`).

Setelah parsing, skrip mengambil IP VPS melalui `curl -s ipinfo.io/ip` (`zidstoretunnel.sh:298`). Kemudian skrip memvalidasi kunci lisensi ke `ZIDSTORE_API_URL/api/key` (`zidstoretunnel.sh:299-300`). Jika respon kosong atau dimulai dengan `Error`, skrip keluar (`zidstoretunnel.sh:301-306`). Kunci dan IP disimpan ke variabel `key` dan `ip` (`zidstoretunnel.sh:307-308`).

## Tahap 2: Input Domain dan Verifikasi DNS A Record

Jika argumen pertama tidak disediakan, skrip meminta input domain (`zidstoretunnel.sh:424-435`). Skrip mengambil IP VPS dan IP domain, lalu membandingkannya (`zidstoretunnel.sh:439-464`):

```
vps_ip=$(curl -s ipinfo.io/ip)
domain_ip=$(getent ahosts $domain | awk '{print $1}' | head -n 1)
if [ "$domain_ip" != "$vps_ip" ]; then
    echo "Domain is not connected to the VPS IP. Please check again."
    exit 1
fi
```

Jika IP domain tidak sama dengan IP VPS, skrip keluar. Domain disimpan ke `/etc/xray/domain` (`zidstoretunnel.sh:466`).

## Tahap 3: Pembersihan Firewall Lama dan Penyiapan iptables

Skrip menghapus package `ufw` dan `firewalld` jika terinstal (`zidstoretunnel.sh:585-603`). Skrip juga menghapus `exim4` (`zidstoretunnel.sh:575-583`) dan mengonfigurasi `iptables-persistent` (`zidstoretunnel.sh:605-620`).

Setelah instalasi dependensi, skrip menambahkan aturan iptables (`zidstoretunnel.sh:1162-1175`):

```
iptables -t nat -A PREROUTING -i $interface -p udp -m udp --dport 53 -j REDIRECT --to-ports 5300
iptables -t nat -A POSTROUTING -s 20.8.0.0/24 -o $interface -j MASQUERADE
```

Aturan disimpan ke `/etc/iptables/rules.v4` (`zidstoretunnel.sh:1198-1202`).

## Tahap 4: Instalasi Dependensi OS, NodeSource, Repo Nginx, HAProxy

Skrip memperbarui sistem dan menginstal paket dasar (`zidstoretunnel.sh:622-671`). Daftar paket mencakup `libnss3-dev`, `libssl-dev`, `dropbear`, `iptables`, `iptables-persistent`, `netfilter-persistent`, dan lainnya (`zidstoretunnel.sh:645-656`).

Node.js diinstal via NodeSource setup 22.x (`zidstoretunnel.sh:706-727`). Skrip mengunduh setup ke berkas sementara, memverifikasi checksum SHA256 terhadap manifest `checksums.txt`, baru mengeksekusi dengan `sudo -E bash`. Gagal unduhan atau verifikasi menghentikan instalasi (fail closed).

```
_setup_tmp=$(mktemp)
curl -fsSL -o "$_setup_tmp" https://deb.nodesource.com/setup_22.x
verify_sha256 "$_setup_tmp" "setup_22.x"
sudo -E bash "$_setup_tmp"
apt-get install -y nodejs
npm install -g npm@latest
```

Nginx diinstal dari repo nginx.org, dengan GPG key (`zidstoretunnel.sh:775-777` untuk Ubuntu, `zidstoretunnel.sh:806-808` untuk Debian).

HAProxy diinstal berdasarkan OS dan versi (`zidstoretunnel.sh:825-872`):
- Ubuntu 18.04: HAProxy 2.6 via PPA
- Ubuntu 20.04: HAProxy 2.9 via PPA
- Ubuntu 22.04: HAProxy 3.0 via PPA
- Ubuntu 24.04: HAProxy 3.0 via PPA
- Debian 10: HAProxy 2.6 via backports
- Debian 11: HAProxy 3.0 via backports
- Debian 12: HAProxy 3.0 via backports
- Debian 13: HAProxy dari repo default

## Tahap 4b: Izin Least-Privilege pada Direktori dan Berkas

Skrip menetapkan izin direktori dan berkas instalasi dengan model least-privilege (mode dan owner:group spesifik): direktori diatur melalui `DIR_PERMS` (`zidstoretunnel.sh:389-411`) dan berkas melalui `FILE_PERMS` (`zidstoretunnel.sh:468-494`), masing-masing diterapkan dalam loop `chmod`/`chown`.

## Tahap 5: Setup SSL Let's Encrypt via acme.sh dan Kompilasi yha.pem

Skrip menghentikan haproxy dan nginx (`zidstoretunnel.sh:1260-1263`), lalu menginstal acme.sh jika belum ada (`zidstoretunnel.sh:1264-1281`). Skrip mengupgrade acme.sh dan mengatur default CA ke Let's Encrypt (`zidstoretunnel.sh:1283-1285`):

```
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
```

Sertifikat dan kunci digabungkan menjadi `/etc/haproxy/yha.pem` (`zidstoretunnel.sh:1296`):

```
cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/yha.pem
```

Ownership file disesuaikan ke `www-data` (`zidstoretunnel.sh:1297-1298`).

## Tahap 6: Download Aset fodder/src-bin/bot dari API Server

Skrip mengunduh `src.zip` dari API server dan mengekstraknya ke `/tmp/src`, lalu menyalin isinya ke `/usr/bin/` (`zidstoretunnel.sh:965-975`):

```
zid_download "$file_dir" /tmp/src.zip "src.zip"
unzip -o /tmp/src.zip -d /tmp/src
cp -r /tmp/src/* /usr/bin/
```

Dropbear, sshd, banner, common-password, ws.py, gotop, haproxy.cfg, xray.conf, nginx.conf, badvpn, vmess.json, vless.json, trojan.json, shadowsocks.json, udp-custom, dan bot.zip diunduh dari `BASE_URL` (`zidstoretunnel.sh:506-524`). Dua URL baru untuk SlowDNS/DNSTT juga ada di blok URL (`zidstoretunnel.sh:518-519`): `dnstt_server_url` dan `dnstt_client_url`. Fungsi `download_file` (`zidstoretunnel.sh:881-926`) menyediakan fallback ke ZidStore API server jika GitHub tidak tersedia.

## Tahap 7: Konfigurasi sysctl, Aktivasi TCP BBR, Swap 2GB

Skrip mengaktifkan `net.ipv4.ip_forward=1` (`zidstoretunnel.sh:1177-1185`):

```
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
fi
sysctl -p
```

Skrip meningkatkan buffer socket UDP untuk BadVPN udpgw (`zidstoretunnel.sh:1187-1195`):

```
echo "net.core.wmem_max=8388608" >> /etc/sysctl.conf
echo "net.core.rmem_max=8388608" >> /etc/sysctl.conf
sysctl -w net.core.wmem_max=8388608
sysctl -w net.core.rmem_max=8388608
```

Skrip membuat swap file 2GB (`zidstoretunnel.sh:1646-1659`):

```
swap_file="/swapfile"
swap_size="2G"
fallocate -l $swap_size $swap_file
chmod 600 $swap_file
mkswap $swap_file
swapon $swap_file
echo "$swap_file swap swap defaults 0 0" >> /etc/fstab
```

Catatan: README lama menyebutkan ukuran swap lebih besar (`README.md:136`), tetapi skrip utama menggunakan 2G (`zidstoretunnel.sh:1647`).

## Tahap 8: Setup Cron Job dan Aktivasi Unit Systemd

Skrip membuat cron job untuk eksekusi harian (`zidstoretunnel.sh:1316-1321`):

```
cat >/etc/cron.d/xp_all <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/bin/exp
EOF
```

Sejak v1.0.3 cron reboot harian dihapus. Instalasi tidak memaksa reboot: mode interaktif menanyakan reboot dengan timeout 60 detik (`zidstoretunnel.sh:1876-1885`); mode non-interaktif selesai tanpa reboot.

Skrip membuat cron job pembersihan log setiap 6 jam (`zidstoretunnel.sh:1369-1373`):

```
cat >/etc/cron.d/logclear <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 */6 * * * root /usr/bin/logclear
EOF
```

Skrip membuat unit systemd untuk vmess, vless, trojan, shadowsocks (`zidstoretunnel.sh:1386-1416`), ws (`zidstoretunnel.sh:1444-1462`), udp (`zidstoretunnel.sh:1464-1485`), limitip (`zidstoretunnel.sh:1487-1504`), limitquota (`zidstoretunnel.sh:1506-1523`), dan badvpn (`zidstoretunnel.sh:1525-1545`). Unit dnstt-server dibuat/diaktifkan secara KONDISIONAL saat domain tersedia.

Skrip mengaktifkan dan memulai semua unit systemd (`zidstoretunnel.sh:1662-1688`). Unit dnstt-server dibuat dan diaktifkan secara KONDISIONAL saat domain tersedia (blok `zidstoretunnel.sh:1693-1790`):

```
services=(
    "vmess@config.service"
    "vless@config.service"
    "trojan@config.service"
    "shadowsocks@config.service"
    "haproxy.service"
    "ws.service"
    "udp.service"
    "limitip.service"
    "limitquota.service"
    "badvpn.service"
    "nginx.service"
    "ssh.service"
    "dropbear.service"
)
for service in "${services[@]}"; do
    sudo systemctl enable $service
    sudo systemctl start $service
    sudo systemctl restart $service
done
```

Blok SlowDNS/DNSTT di `zidstoretunnel.sh:1693-1790`: unduh biner `dnstt-server` dan `dnstt-client` dari fodder dengan verifikasi sha256; buat `/etc/slowdns` mode 700; kunci dibuat dengan `-gen-key` bila belum ada (server.key 600, server.pub 644); tentukan domain dengan prioritas unit existing > `/etc/slowdns/domain` > env `DNSTT_DOMAIN` > otomatis via API (`zidstoretunnel.sh:1741-1746`, dipanggil bila ketiganya kosong; POST /api/slowdns/register dengan domain install, fail-open), lalu divalidasi; hasil domain API ditulis ke `/etc/slowdns/domain`; telemetri `slowdns_ready` menambah field "source" (unit/file/env/api); tulis unit systemd `dnstt-server.service` serta enable/start bila domain valid; kirim telemetri `slowdns_ready`/`slowdns_skipped`; seluruh blok fail-open dan idempoten.

Instalasi mengirim telemetri progres ke server dan mencetak `Install ID` di akhir; rincian di `07-jebakan-dan-troubleshooting.md`.

## Rujukan Berkas:Baris

| Berkas:Baris | Fungsi |
|---|---|
| `zidstoretunnel.sh:18-87` | Parsing argumen --key |
| `zidstoretunnel.sh:89-166` | Handle --update flag |
| `zidstoretunnel.sh:168-172` | Handle --version flag |
| `zidstoretunnel.sh:265-295` | Validasi INSTALL_KEY kosong |
| `zidstoretunnel.sh:298-300` | Validasi lisensi ke API server |
| `zidstoretunnel.sh:301-306` | Handle respon error validasi |
| `zidstoretunnel.sh:307-308` | Simpan key dan ip |
| `zidstoretunnel.sh:424-435` | Input domain interaktif |
| `zidstoretunnel.sh:439-464` | Verifikasi DNS A record |
| `zidstoretunnel.sh:466` | Simpan domain ke /etc/xray/domain |
| `zidstoretunnel.sh:468-486` | Pembuatan berkas konfigurasi |
| `zidstoretunnel.sh:496-501` | Variabel default timezone, city, isp |
| `zidstoretunnel.sh:504-524` | Definisi URL sumber daya |
| `zidstoretunnel.sh:622-626` | apt update |
| `zidstoretunnel.sh:548-554` | Instal sudo |
| `zidstoretunnel.sh:556-562` | Instal debconf-utils |
| `zidstoretunnel.sh:564-572` | Instal software-properties-common (Ubuntu) |
| `zidstoretunnel.sh:575-583` | Hapus exim4 |
| `zidstoretunnel.sh:585-603` | Hapus ufw dan firewalld |
| `zidstoretunnel.sh:605-620` | Konfigurasi iptables-persistent |
| `zidstoretunnel.sh:645-656` | Daftar paket OS |
| `zidstoretunnel.sh:663-671` | Loop instalasi paket |
| `zidstoretunnel.sh:706-727` | Instal Node.js via NodeSource 22.x |
| `zidstoretunnel.sh:752-821` | Konfigurasi OS spesifik (Ubuntu/Debian) |
| `zidstoretunnel.sh:825-872` | Instalasi HAProxy per OS/versi |
| `zidstoretunnel.sh:881-926` | Fungsi download_file dengan fallback |
| `zidstoretunnel.sh:928-963` | Fungsi zid_download |
| `zidstoretunnel.sh:965-975` | Unduh dan ekstrak src.zip |
| `zidstoretunnel.sh:977-992` | Unduh dropbear dan konfigurasi |
| `zidstoretunnel.sh:994-1023` | Unduh sshd_config |
| `zidstoretunnel.sh:1025-1031` | Unduh banner zidstoretunnel.txt |
| `zidstoretunnel.sh:1033-1047` | Unduh common-password |
| `zidstoretunnel.sh:1049-1055` | Unduh ws.py |
| `zidstoretunnel.sh:1057-1069` | Instal gotop |
| `zidstoretunnel.sh:1071-1088` | Unduh haproxy.cfg |
| `zidstoretunnel.sh:1090-1095` | Unduh xray.conf |
| `zidstoretunnel.sh:1097-1123` | Unduh konfigurasi Xray (vmess, vless, trojan, shadowsocks) |
| `zidstoretunnel.sh:1125-1130` | Unduh udp-custom |
| `zidstoretunnel.sh:1132-1137` | Unduh nginx.conf |
| `zidstoretunnel.sh:1139-1148` | Unduh badvpn |
| `zidstoretunnel.sh:1152-1175` | Aturan iptables |
| `zidstoretunnel.sh:1177-1185` | Konfigurasi ip_forward |
| `zidstoretunnel.sh:1187-1195` | Buffer UDP socket |
| `zidstoretunnel.sh:1197-1202` | Simpan aturan iptables |
| `zidstoretunnel.sh:1205-1249` | Instal Xray Core |
| `zidstoretunnel.sh:1256-1301` | Setup SSL acme.sh |
| `zidstoretunnel.sh:1304-1314` | Pembuatan /usr/bin/config.json |
| `zidstoretunnel.sh:1316-1321` | Cron job xp_all |
| `zidstoretunnel.sh:1323-1345` | Pembuatan .profile dan .bashrc |
| `zidstoretunnel.sh:1347-1367` | Pembuatan /etc/shells |
| `zidstoretunnel.sh:179-280` | Inisialisasi telemetri (helpers, trap, log lokal) |
| `zidstoretunnel.sh:1369-1373` | Cron job logclear |
| `zidstoretunnel.sh:1375` | Restart cron service |
| `zidstoretunnel.sh:1386-1410` | Fungsi create_service |
| `zidstoretunnel.sh:1412-1416` | Pembuatan unit vmess/vless/trojan/shadowsocks |
| `zidstoretunnel.sh:1418-1424` | Konfigurasi xray@.service.d |
| `zidstoretunnel.sh:1426-1437` | Disable xray dan dropbear |
| `zidstoretunnel.sh:1444-1462` | Pembuatan ws.service |
| `zidstoretunnel.sh:1464-1485` | Pembuatan udp.service |
| `zidstoretunnel.sh:1487-1504` | Pembuatan limitip.service |
| `zidstoretunnel.sh:1506-1523` | Pembuatan limitquota.service |
| `zidstoretunnel.sh:1525-1545` | Pembuatan badvpn.service |
| `zidstoretunnel.sh:1554-1559` | Simpan key ke `/root/.key` dengan `chmod 600` dan `chown root:root` |
| `zidstoretunnel.sh:1561-1568` | Ganti UUID di semua config Xray |
| `zidstoretunnel.sh:1569` | Instal npm express (pin versi + ignore-scripts) |
| `zidstoretunnel.sh:1571-1642` | Fungsi setup_bot |
| `zidstoretunnel.sh:1644` | Panggil setup_bot |
| `zidstoretunnel.sh:1647-1659` | Pembuatan swap file 2G |
| `zidstoretunnel.sh:1662-1688` | Aktivasi dan start unit systemd (dnstt-server kondisional) |
| `zidstoretunnel.sh:1691` | Restart netfilter-persistent |
| `zidstoretunnel.sh:1693-1790` | Blok SlowDNS/DNSTT fase 1 (unduh biner + verify, /etc/slowdns 700, kunci, domain, unit + enable/start bila domain ada, telemetri, fail-open) |
| `zidstoretunnel.sh:1741-1746` | Panggilan API otomatis subdomain DNSTT (fallback ke-4, fail-open) |
| `zidstoretunnel.sh:1828-1830` | Fail-fast kondisional blok dnstt-server (saat unit terpasang) |
| `zidstoretunnel.sh:1861-1890` | Pesan selesai, Install ID, prompt reboot interaktif |
