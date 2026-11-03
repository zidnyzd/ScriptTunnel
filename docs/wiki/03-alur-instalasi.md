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

Skrip menghapus package `ufw` dan `firewalld` jika terinstal (`zidstoretunnel.sh:584-602`). Skrip juga menghapus `exim4` (`zidstoretunnel.sh:574-582`) dan mengonfigurasi `iptables-persistent` (`zidstoretunnel.sh:604-619`).

Setelah instalasi dependensi, skrip menambahkan aturan iptables (`zidstoretunnel.sh:1161-1178`):

```
iptables -t nat -A PREROUTING -i $interface -p udp -m udp --dport 53 -j REDIRECT --to-ports 5300
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $interface -j MASQUERADE
iptables -t nat -A POSTROUTING -s 20.8.0.0/24 -o $interface -j MASQUERADE
```

Aturan disimpan ke `/etc/iptables/rules.v4` (`zidstoretunnel.sh:1201-1205`).

## Tahap 4: Instalasi Dependensi OS, NodeSource, Repo Nginx, HAProxy

Skrip memperbarui sistem dan menginstal paket dasar (`zidstoretunnel.sh:621-670`). Daftar paket mencakup `libnss3-dev`, `libssl-dev`, `openvpn`, `easy-rsa`, `dropbear`, `iptables`, `iptables-persistent`, `netfilter-persistent`, dan lainnya (`zidstoretunnel.sh:644-655`).

Node.js diinstal via NodeSource setup 22.x (`zidstoretunnel.sh:705-726`). Skrip mengunduh setup ke berkas sementara, memverifikasi checksum SHA256 terhadap manifest `checksums.txt`, baru mengeksekusi dengan `sudo -E bash`. Gagal unduhan atau verifikasi menghentikan instalasi (fail closed).

```
_setup_tmp=$(mktemp)
curl -fsSL -o "$_setup_tmp" https://deb.nodesource.com/setup_22.x
verify_sha256 "$_setup_tmp" "setup_22.x"
sudo -E bash "$_setup_tmp"
apt-get install -y nodejs
npm install -g npm@latest
```

Nginx diinstal dari repo nginx.org, dengan GPG key (`zidstoretunnel.sh:774-776` untuk Ubuntu, `zidstoretunnel.sh:805-807` untuk Debian).

HAProxy diinstal berdasarkan OS dan versi (`zidstoretunnel.sh:824-871`):
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

Skrip menghentikan haproxy dan nginx (`zidstoretunnel.sh:1263-1266`), lalu menginstal acme.sh jika belum ada (`zidstoretunnel.sh:1267-1284`). Skrip mengupgrade acme.sh dan mengatur default CA ke Let's Encrypt (`zidstoretunnel.sh:1286-1288`):

```
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
```

Sertifikat dan kunci digabungkan menjadi `/etc/haproxy/yha.pem` (`zidstoretunnel.sh:1299`):

```
cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/yha.pem
```

Ownership file disesuaikan ke `www-data` (`zidstoretunnel.sh:1300-1301`).

## Tahap 6: Download Aset fodder/src-bin/bot dari API Server

Skrip mengunduh `src.zip` dari API server dan mengekstraknya ke `/tmp/src`, lalu menyalin isinya ke `/usr/bin/` (`zidstoretunnel.sh:964-974`):

```
zid_download "$file_dir" /tmp/src.zip "src.zip"
unzip -o /tmp/src.zip -d /tmp/src
cp -r /tmp/src/* /usr/bin/
```

Dropbear, sshd, banner, common-password, ws.py, gotop, haproxy.cfg, xray.conf, nginx.conf, badvpn, openvpn.zip, vmess.json, vless.json, trojan.json, shadowsocks.json, udp-custom, dan bot.zip diunduh dari `BASE_URL` (`zidstoretunnel.sh:506-523`). Fungsi `download_file` (`zidstoretunnel.sh:880-925`) menyediakan fallback ke ZidStore API server jika GitHub tidak tersedia.

## Tahap 7: Konfigurasi sysctl, Aktivasi TCP BBR, Swap 2GB

Skrip mengaktifkan `net.ipv4.ip_forward=1` (`zidstoretunnel.sh:1180-1188`):

```
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
fi
sysctl -p
```

Skrip meningkatkan buffer socket UDP untuk BadVPN udpgw (`zidstoretunnel.sh:1190-1198`):

```
echo "net.core.wmem_max=8388608" >> /etc/sysctl.conf
echo "net.core.rmem_max=8388608" >> /etc/sysctl.conf
sysctl -w net.core.wmem_max=8388608
sysctl -w net.core.rmem_max=8388608
```

Skrip membuat swap file 2GB (`zidstoretunnel.sh:1772-1785`):

```
swap_file="/swapfile"
swap_size="2G"
fallocate -l $swap_size $swap_file
chmod 600 $swap_file
mkswap $swap_file
swapon $swap_file
echo "$swap_file swap swap defaults 0 0" >> /etc/fstab
```

Catatan: README lama menyebutkan ukuran swap lebih besar (`README.md:136`), tetapi skrip utama menggunakan 2G (`zidstoretunnel.sh:1773`).

## Tahap 8: Setup Cron Job dan Aktivasi Unit Systemd

Skrip membuat cron job untuk eksekusi harian (`zidstoretunnel.sh:1442-1447`):

```
cat >/etc/cron.d/xp_all <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/bin/exp
EOF
```

Sejak v1.0.3 cron reboot harian dihapus. Instalasi tidak memaksa reboot: mode interaktif menanyakan reboot dengan timeout 60 detik (`zidstoretunnel.sh:1882-1891`); mode non-interaktif selesai tanpa reboot.

Skrip membuat cron job pembersihan log setiap 6 jam (`zidstoretunnel.sh:1495-1499`):

```
cat >/etc/cron.d/logclear <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 */6 * * * root /usr/bin/logclear
EOF
```

Skrip membuat unit systemd untuk vmess, vless, trojan, shadowsocks (`zidstoretunnel.sh:1512-1542`), ws (`zidstoretunnel.sh:1570-1588`), udp (`zidstoretunnel.sh:1590-1611`), limitip (`zidstoretunnel.sh:1613-1630`), limitquota (`zidstoretunnel.sh:1632-1649`), dan badvpn (`zidstoretunnel.sh:1651-1671`).

Skrip mengaktifkan dan memulai semua unit systemd (`zidstoretunnel.sh:1788-1814`):

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
| `zidstoretunnel.sh:504-523` | Definisi URL sumber daya |
| `zidstoretunnel.sh:621-625` | apt update |
| `zidstoretunnel.sh:547-553` | Instal sudo |
| `zidstoretunnel.sh:555-561` | Instal debconf-utils |
| `zidstoretunnel.sh:563-571` | Instal software-properties-common (Ubuntu) |
| `zidstoretunnel.sh:574-582` | Hapus exim4 |
| `zidstoretunnel.sh:584-602` | Hapus ufw dan firewalld |
| `zidstoretunnel.sh:604-619` | Konfigurasi iptables-persistent |
| `zidstoretunnel.sh:644-655` | Daftar paket OS |
| `zidstoretunnel.sh:662-670` | Loop instalasi paket |
| `zidstoretunnel.sh:705-726` | Instal Node.js via NodeSource 22.x |
| `zidstoretunnel.sh:751-820` | Konfigurasi OS spesifik (Ubuntu/Debian) |
| `zidstoretunnel.sh:824-871` | Instalasi HAProxy per OS/versi |
| `zidstoretunnel.sh:880-925` | Fungsi download_file dengan fallback |
| `zidstoretunnel.sh:927-962` | Fungsi zid_download |
| `zidstoretunnel.sh:964-974` | Unduh dan ekstrak src.zip |
| `zidstoretunnel.sh:976-991` | Unduh dropbear dan konfigurasi |
| `zidstoretunnel.sh:993-1022` | Unduh sshd_config |
| `zidstoretunnel.sh:1024-1030` | Unduh banner zidstoretunnel.txt |
| `zidstoretunnel.sh:1032-1046` | Unduh common-password |
| `zidstoretunnel.sh:1048-1054` | Unduh ws.py |
| `zidstoretunnel.sh:1056-1068` | Instal gotop |
| `zidstoretunnel.sh:1070-1087` | Unduh haproxy.cfg |
| `zidstoretunnel.sh:1089-1094` | Unduh xray.conf |
| `zidstoretunnel.sh:1096-1122` | Unduh konfigurasi Xray (vmess, vless, trojan, shadowsocks) |
| `zidstoretunnel.sh:1124-1129` | Unduh udp-custom |
| `zidstoretunnel.sh:1131-1136` | Unduh nginx.conf |
| `zidstoretunnel.sh:1138-1147` | Unduh badvpn |
| `zidstoretunnel.sh:1151-1178` | Aturan iptables |
| `zidstoretunnel.sh:1180-1188` | Konfigurasi ip_forward |
| `zidstoretunnel.sh:1190-1198` | Buffer UDP socket |
| `zidstoretunnel.sh:1200-1205` | Simpan aturan iptables |
| `zidstoretunnel.sh:1208-1252` | Instal Xray Core |
| `zidstoretunnel.sh:1259-1304` | Setup SSL acme.sh |
| `zidstoretunnel.sh:1305-1325` | Instal OpenVPN dan ekstrak openvpn.zip |
| `zidstoretunnel.sh:1327-1414` | Pembuatan profil ovpn dan input_cert_ovpn |
| `zidstoretunnel.sh:1430-1440` | Pembuatan /usr/bin/config.json |
| `zidstoretunnel.sh:1442-1447` | Cron job xp_all |
| `zidstoretunnel.sh:1449-1471` | Pembuatan .profile dan .bashrc |
| `zidstoretunnel.sh:1473-1493` | Pembuatan /etc/shells |
| `zidstoretunnel.sh:179-280` | Inisialisasi telemetri (helpers, trap, log lokal) |
| `zidstoretunnel.sh:1495-1499` | Cron job logclear |
| `zidstoretunnel.sh:1501` | Restart cron service |
| `zidstoretunnel.sh:1512-1536` | Fungsi create_service |
| `zidstoretunnel.sh:1538-1542` | Pembuatan unit vmess/vless/trojan/shadowsocks |
| `zidstoretunnel.sh:1544-1550` | Konfigurasi xray@.service.d |
| `zidstoretunnel.sh:1552-1563` | Disable xray dan dropbear |
| `zidstoretunnel.sh:1570-1588` | Pembuatan ws.service |
| `zidstoretunnel.sh:1590-1611` | Pembuatan udp.service |
| `zidstoretunnel.sh:1613-1630` | Pembuatan limitip.service |
| `zidstoretunnel.sh:1632-1649` | Pembuatan limitquota.service |
| `zidstoretunnel.sh:1651-1671` | Pembuatan badvpn.service |
| `zidstoretunnel.sh:1680-1685` | Simpan key ke `/root/.key` dengan `chmod 600` dan `chown root:root` |
| `zidstoretunnel.sh:1687-1694` | Ganti UUID di semua config Xray |
| `zidstoretunnel.sh:1695` | Instal npm express (pin versi + ignore-scripts) |
| `zidstoretunnel.sh:1697-1768` | Fungsi setup_bot |
| `zidstoretunnel.sh:1770` | Panggil setup_bot |
| `zidstoretunnel.sh:1771-1785` | Pembuatan swap file 2G |
| `zidstoretunnel.sh:1788-1814` | Aktivasi dan start unit systemd |
| `zidstoretunnel.sh:1817` | Restart netfilter-persistent |
| `zidstoretunnel.sh:1867-1896` | Pesan selesai, Install ID, prompt reboot interaktif |
