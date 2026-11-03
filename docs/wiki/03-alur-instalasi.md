# 03 Alur Instalasi

## Tahap 1: Argument Parsing (--key) dan Verifikasi Lisensi IP

Skrip utama `zidstoretunnel.sh` dimulai dengan parsing argumen (`zidstoretunnel.sh:14-25`). Argumen `--key=VALUE` atau `--key VALUE` disimpan ke variabel `INSTALL_KEY`. Jika `INSTALL_KEY` kosong, skrip keluar dengan pesan error (`zidstoretunnel.sh:60-65`).

Setelah parsing, skrip mengambil IP VPS melalui `curl -s ipinfo.io/ip` (`zidstoretunnel.sh:68`). Kemudian skrip memvalidasi kunci lisensi ke `ZIDSTORE_API_URL/api/key` (`zidstoretunnel.sh:69-70`). Jika respon kosong atau dimulai dengan `Error`, skrip keluar (`zidstoretunnel.sh:71-75`). Kunci dan IP disimpan ke variabel `key` dan `ip` (`zidstoretunnel.sh:76-77`).

## Tahap 2: Input Domain dan Verifikasi DNS A Record

Jika argumen pertama tidak disediakan, skrip meminta input domain (`zidstoretunnel.sh:116-127`). Skrip mengambil IP VPS dan IP domain, lalu membandingkannya (`zidstoretunnel.sh:130-136`):

```
vps_ip=$(curl -s ipinfo.io/ip)
domain_ip=$(getent ahosts $domain | awk '{print $1}' | head -n 1)
if [ "$domain_ip" != "$vps_ip" ]; then
    echo "Domain is not connected to the VPS IP. Please check again."
    exit 1
fi
```

Jika IP domain tidak sama dengan IP VPS, skrip keluar. Domain disimpan ke `/etc/xray/domain` (`zidstoretunnel.sh:138`).

## Tahap 3: Pembersihan Firewall Lama dan Penyiapan iptables

Skrip menghapus package `ufw` dan `firewalld` jika terinstal (`zidstoretunnel.sh:258-276`). Skrip juga menghapus `exim4` (`zidstoretunnel.sh:248-256`) dan mengonfigurasi `iptables-persistent` (`zidstoretunnel.sh:278-293`).

Setelah instalasi dependensi, skrip menambahkan aturan iptables (`zidstoretunnel.sh:743-760`):

```
iptables -t nat -A PREROUTING -i $interface -p udp -m udp --dport 53 -j REDIRECT --to-ports 5300
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $interface -j MASQUERADE
iptables -t nat -A POSTROUTING -s 20.8.0.0/24 -o $interface -j MASQUERADE
```

Aturan disimpan ke `/etc/iptables/rules.v4` (`zidstoretunnel.sh:783-787`).

## Tahap 4: Instalasi Dependensi OS, NodeSource, Repo Nginx, HAProxy

Skrip memperbarui sistem dan menginstal paket dasar (`zidstoretunnel.sh:217-339`). Daftar paket mencakup `libnss3-dev`, `libssl-dev`, `openvpn`, `easy-rsa`, `dropbear`, `iptables`, `iptables-persistent`, `netfilter-persistent`, dan lainnya (`zidstoretunnel.sh:314-325`).

Node.js diinstal via NodeSource setup 22.x (`zidstoretunnel.sh:365-371`):

```
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
apt-get install -y nodejs
npm install -g npm@latest
```

Nginx diinstal dari repo nginx.org, dengan GPG key (`zidstoretunnel.sh:414-416` untuk Ubuntu, `zidstoretunnel.sh:445-447` untuk Debian).

HAProxy diinstal berdasarkan OS dan versi (`zidstoretunnel.sh:461-507`):
- Ubuntu 18.04: HAProxy 2.6 via PPA
- Ubuntu 20.04: HAProxy 2.9 via PPA
- Ubuntu 22.04: HAProxy 3.0 via PPA
- Ubuntu 24.04: HAProxy 3.0 via PPA
- Debian 10: HAProxy 2.6 via backports
- Debian 11: HAProxy 3.0 via backports
- Debian 12: HAProxy 3.0 via backports
- Debian 13: HAProxy dari repo default

## Tahap 5: Setup SSL Let's Encrypt via acme.sh dan Kompilasi yha.pem

Skrip menghentikan haproxy dan nginx (`zidstoretunnel.sh:809-812`), lalu menginstal acme.sh jika belum ada (`zidstoretunnel.sh:813-816`). Skrip mengupgrade acme.sh dan mengatur default CA ke Let's Encrypt (`zidstoretunnel.sh:818-820`):

```
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
```

Sertifikat dan kunci digabungkan menjadi `/etc/haproxy/yha.pem` (`zidstoretunnel.sh:823`):

```
cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/yha.pem
```

Ownership file disesuaikan ke `www-data` (`zidstoretunnel.sh:824-825`).

## Tahap 6: Download Aset fodder/src-bin/bot dari API Server

Skrip mengunduh `src.zip` dari API server dan mengekstraknya ke `/tmp/src`, lalu menyalin isinya ke `/usr/bin/` (`zidstoretunnel.sh:584-592`):

```
zid_download "$file_dir" /tmp/src.zip "src.zip"
unzip -o /tmp/src.zip -d /tmp/src
cp -r /tmp/src/* /usr/bin/
```

Dropbear, sshd, banner, common-password, ws.py, gotop, haproxy.cfg, xray.conf, nginx.conf, badvpn, openvpn.zip, vmess.json, vless.json, trojan.json, shadowsocks.json, udp-custom, dan bot.zip diunduh dari `BASE_URL` (`zidstoretunnel.sh:165-183`). Fungsi `download_file` (`zidstoretunnel.sh:510-550`) menyediakan fallback ke ZidStore API server jika GitHub tidak tersedia.

## Tahap 7: Konfigurasi sysctl, Aktivasi TCP BBR, Swap 2GB/5GB

Skrip mengaktifkan `net.ipv4.ip_forward=1` (`zidstoretunnel.sh:762-770`):

```
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
fi
sysctl -p
```

Skrip meningkatkan buffer socket UDP untuk BadVPN udpgw (`zidstoretunnel.sh:772-780`):

```
echo "net.core.wmem_max=8388608" >> /etc/sysctl.conf
echo "net.core.rmem_max=8388608" >> /etc/sysctl.conf
sysctl -w net.core.wmem_max=8388608
sysctl -w net.core.rmem_max=8388608
```

Skrip membuat swap file 2GB (`zidstoretunnel.sh:1222-1235`):

```
swap_file="/swapfile"
swap_size="2G"
fallocate -l $swap_size $swap_file
chmod 600 $swap_file
mkswap $swap_file
swapon $swap_file
echo "$swap_file swap swap defaults 0 0" >> /etc/fstab
```

Catatan: README.md menyebutkan swap 5G (`README.md:136`), tetapi skrip utama menggunakan 2G (`zidstoretunnel.sh:1223`).

## Tahap 8: Setup Cron Job dan Aktivasi Unit Systemd

Skrip membuat cron job untuk eksekusi harian (`zidstoretunnel.sh:961-966`):

```
cat >/etc/cron.d/xp_all <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/bin/exp
EOF
```

Skrip membuat cron job reboot harian 05:00 (`zidstoretunnel.sh:1006-1011`):

```
cat >/etc/cron.d/daily_reboot <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 5 * * * root /sbin/reboot
EOF
```

Skrip membuat cron job pembersihan log setiap 6 jam (`zidstoretunnel.sh:1013-1017`):

```
cat >/etc/cron.d/logclear <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 */6 * * * root /usr/bin/logclear
EOF
```

Skrip membuat unit systemd untuk vmess, vless, trojan, shadowsocks (`zidstoretunnel.sh:1034-1064`), ws (`zidstoretunnel.sh:1086-1104`), udp (`zidstoretunnel.sh:1106-1125`), limitip (`zidstoretunnel.sh:1127-1142`), limitquota (`zidstoretunnel.sh:1144-1159`), dan badvpn (`zidstoretunnel.sh:1161-1179`).

Skrip mengaktifkan dan memulai semua unit systemd (`zidstoretunnel.sh:1236-1262`):

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

## Rujukan Berkas:Baris

| Berkas:Baris | Fungsi |
|---|---|
| `zidstoretunnel.sh:14-25` | Parsing argumen --key |
| `zidstoretunnel.sh:28-39` | Handle --update flag |
| `zidstoretunnel.sh:42-45` | Handle --version flag |
| `zidstoretunnel.sh:60-65` | Validasi INSTALL_KEY kosong |
| `zidstoretunnel.sh:68-70` | Validasi lisensi ke API server |
| `zidstoretunnel.sh:71-75` | Handle respon error validasi |
| `zidstoretunnel.sh:76-77` | Simpan key dan ip |
| `zidstoretunnel.sh:116-127` | Input domain interaktif |
| `zidstoretunnel.sh:130-136` | Verifikasi DNS A record |
| `zidstoretunnel.sh:138` | Simpan domain ke /etc/xray/domain |
| `zidstoretunnel.sh:140-149` | Pembuatan berkas konfigurasi |
| `zidstoretunnel.sh:155-160` | Variabel default timezone, city, isp |
| `zidstoretunnel.sh:163-183` | Definisi URL sumber daya |
| `zidstoretunnel.sh:217-219` | apt update |
| `zidstoretunnel.sh:221-227` | Instal sudo |
| `zidstoretunnel.sh:229-235` | Instal debconf-utils |
| `zidstoretunnel.sh:237-245` | Instal software-properties-common (Ubuntu) |
| `zidstoretunnel.sh:248-256` | Hapus exim4 |
| `zidstoretunnel.sh:258-276` | Hapus ufw dan firewalld |
| `zidstoretunnel.sh:278-293` | Konfigurasi iptables-persistent |
| `zidstoretunnel.sh:314-325` | Daftar paket OS |
| `zidstoretunnel.sh:327-339` | Loop instalasi paket |
| `zidstoretunnel.sh:365-371` | Instal Node.js via NodeSource 22.x |
| `zidstoretunnel.sh:391-459` | Konfigurasi OS spesifik (Ubuntu/Debian) |
| `zidstoretunnel.sh:461-507` | Instalasi HAProxy per OS/versi |
| `zidstoretunnel.sh:510-550` | Fungsi download_file dengan fallback |
| `zidstoretunnel.sh:552-582` | Fungsi zid_download |
| `zidstoretunnel.sh:584-592` | Unduh dan ekstrak src.zip |
| `zidstoretunnel.sh:594-609` | Unduh dropbear dan konfigurasi |
| `zidstoretunnel.sh:611-621` | Unduh sshd_config |
| `zidstoretunnel.sh:623-629` | Unduh banner zidstoretunnel.txt |
| `zidstoretunnel.sh:631-636` | Unduh common-password |
| `zidstoretunnel.sh:638-644` | Unduh ws.py |
| `zidstoretunnel.sh:652-664` | Instal gotop |
| `zidstoretunnel.sh:666-683` | Unduh haproxy.cfg |
| `zidstoretunnel.sh:685-690` | Unduh xray.conf |
| `zidstoretunnel.sh:692-718` | Unduh konfigurasi Xray (vmess, vless, trojan, shadowsocks) |
| `zidstoretunnel.sh:720-724` | Unduh udp-custom |
| `zidstoretunnel.sh:726-731` | Unduh nginx.conf |
| `zidstoretunnel.sh:733-738` | Unduh badvpn |
| `zidstoretunnel.sh:740-760` | Aturan iptables |
| `zidstoretunnel.sh:762-770` | Konfigurasi ip_forward |
| `zidstoretunnel.sh:772-780` | Buffer UDP socket |
| `zidstoretunnel.sh:782-787` | Simpan aturan iptables |
| `zidstoretunnel.sh:789-803` | Instal Xray Core |
| `zidstoretunnel.sh:805-826` | Setup SSL acme.sh |
| `zidstoretunnel.sh:827-846` | Instal OpenVPN dan ekstrak openvpn.zip |
| `zidstoretunnel.sh:848-935` | Pembuatan profil ovpn dan input_cert_ovpn |
| `zidstoretunnel.sh:949-959` | Pembuatan /usr/bin/config.json |
| `zidstoretunnel.sh:961-966` | Cron job xp_all |
| `zidstoretunnel.sh:968-985` | Pembuatan .profile dan .bashrc |
| `zidstoretunnel.sh:987-1001` | Pembuatan /etc/shells |
| `zidstoretunnel.sh:1006-1011` | Cron job daily_reboot |
| `zidstoretunnel.sh:1013-1017` | Cron job logclear |
| `zidstoretunnel.sh:1019` | Restart cron service |
| `zidstoretunnel.sh:1021-1024` | Simpan daily_reboot time |
| `zidstoretunnel.sh:1034-1058` | Fungsi create_service |
| `zidstoretunnel.sh:1060-1064` | Pembuatan unit vmess/vless/trojan/shadowsocks |
| `zidstoretunnel.sh:1066-1071` | Konfigurasi xray@.service.d |
| `zidstoretunnel.sh:1073-1084` | Disable xray dan dropbear |
| `zidstoretunnel.sh:1086-1104` | Pembuatan ws.service |
| `zidstoretunnel.sh:1106-1125` | Pembuatan udp.service |
| `zidstoretunnel.sh:1127-1142` | Pembuatan limitip.service |
| `zidstoretunnel.sh:1144-1159` | Pembuatan limitquota.service |
| `zidstoretunnel.sh:1161-1179` | Pembuatan badvpn.service |
| `zidstoretunnel.sh:1181-1184` | Simpan key ke /root/.key |
| `zidstoretunnel.sh:1186-1189` | Ganti UUID di semua config Xray |
| `zidstoretunnel.sh:1190` | Instal npm express express-fileupload |
| `zidstoretunnel.sh:1192-1218` | Fungsi setup_bot |
| `zidstoretunnel.sh:1220` | Panggil setup_bot |
| `zidstoretunnel.sh:1221-1235` | Pembuatan swap file 2G |
| `zidstoretunnel.sh:1236-1262` | Aktivasi dan start unit systemd |
| `zidstoretunnel.sh:1263` | Restart netfilter-persistent |
| `zidstoretunnel.sh:1269-1277` | Pesan selesai dan reboot |
