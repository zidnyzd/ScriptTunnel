# 06 Konfigurasi dan Jaringan

## Variabel Konfigurasi Default

Berikut adalah variabel default yang terdokumentasi di README:

| Variabel | Default | Deskripsi | Rujukan |
|---|---|---|---|
| `domain_ns` | `<sub>.zdnstt.web.id` (per VPS) | Domain SlowDNS per VPS via `/etc/slowdns/domain` atau env `DNSTT_DOMAIN` (bukan domain lama `dnstt.me`) | `08-slowdns-ops.md` |
| `timezone` | `Asia/Jakarta` | Timezone server | `README.md:65`, `zidstoretunnel.sh:496` |
| `cf_id` | (wajib diisi pengguna) | Cloudflare API email | `README.md:66` |
| `cf_key` | (wajib diisi pengguna) | Cloudflare Global API Key | `README.md:67` |
| `swap_size` | `2G` | Ukuran swap file v1.0.3 | `README.md:68` |

Namun, implementasi di skrip utama menunjukkan:

- `timezone="Asia/Jakarta"` didefinisikan di `zidstoretunnel.sh:496`.
- `swap_size="2G"` didefinisikan di `zidstoretunnel.sh:1647` (bukan ukuran swap yang lebih besar).
- `domain_ns`, `cf_id`, `cf_key` tidak ditemukan di `zidstoretunnel.sh` atau di berkas konfigurasi repo. Variabel-variabel ini kemungkinan digunakan oleh aset yang diunduh dari API server (bot atau skrip manajemen) saat runtime.
- `ZIDSTORE_VERSION="1.0.3"` di `zidstoretunnel.sh:8`, `VERSION` berisi `1.0.3`.

## Aturan iptables Lengkap

### PREROUTING

DNS dari luar ke port 53 di-redirect ke port 5300 (SlowDNS):

```
iptables -t nat -A PREROUTING -i $interface -p udp -m udp --dport 53 -j REDIRECT --to-ports 5300
```

Rujukan: `zidstoretunnel.sh:1163`.

### POSTROUTING MASQUERADE

Routing untuk jaringan VPN client:

```
iptables -t nat -A POSTROUTING -s 20.8.0.0/24 -o $interface -j MASQUERADE
```

Rujukan: `zidstoretunnel.sh:1171-1175`.

Interface ditentukan secara dinamis:

```
interface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
```

Rujukan: `zidstoretunnel.sh:1153`.

Semua aturan disimpan dengan `iptables-save` ke `/etc/iptables/rules.v4`:

```
iptables-save >/etc/iptables/rules.v4
```

Rujukan: `zidstoretunnel.sh:1164`, `zidstoretunnel.sh:1172`, `zidstoretunnel.sh:1198-1202`.

## Tuning Kernel Linux

### IP Forwarding

Mengaktifkan routing antar interface:

```
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
fi
sysctl -p
```

Rujukan: `zidstoretunnel.sh:1177-1185`.

### TCP BBR

README menyebutkan "TCP BBR congestion control" (`README.md:20`). Tidak ada baris eksplisit yang menjalankan `modprobe tcp_bbr` atau menambahkan `net.core.default_qdisc=fq` dan `net.ipv4.tcp_congestion_control=bbr` di `zidstoretunnel.sh`. Ini bisa berarti BBR diaktifkan oleh infrastruktur atau oleh paket kernel tertentu, atau konfigurasi ada di aset yang diunduh. Perlu diverifikasi saat instalasi, namun tidak ada rujukan kode yang jelas di repo ini.

### UDP Buffer

Meningkatkan buffer untuk mencegah "out of UDP buffer" pada BadVPN:

```
echo "net.core.wmem_max=8388608" >> /etc/sysctl.conf
echo "net.core.rmem_max=8388608" >> /etc/sysctl.conf
sysctl -w net.core.wmem_max=8388608
sysctl -w net.core.rmem_max=8388608
```

Rujukan: `zidstoretunnel.sh:1187-1195`.

## Manajemen Rotasi Log

### Cron Logclear

Pembersihan log dijalankan setiap 6 jam:

```
cat >/etc/cron.d/logclear <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/srsbin:/usr/bin (catatan typo tidak ada)
0 */6 * * * root /usr/bin/logclear
EOF
```

Rujukan: `zidstoretunnel.sh:1369-1373`. Skrip logclear diunduh sebagai bagian dari `src.zip` ke `/usr/bin/` (`zidstoretunnel.sh:965-975`).

README menyebutkan "Log rotation every 6 hours" (`README.md:138`).

### Cron Reboot Terjadwal

Sejak v1.0.3 cron reboot harian dihapus; tidak ada jadwal reboot otomatis.

### Cron Expire

Pembersihan akun yang kadaluarsa dijalankan setiap hari pada 02:00:

```
cat >/etc/cron.d/xp_all <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/bin/exp
EOF
```

Rujukan: `zidstoretunnel.sh:1316-1321`.

## Swap

Swap dibuat dengan ukuran 2G:

```
swap_file="/swapfile"
swap_size="2G"
fallocate -l $swap_size $swap_file
chmod 600 $swap_file
mkswap $swap_file
swapon $swap_file
echo "$swap_file swap swap defaults 0 0" >> /etc/fstab
```

Rujukan: `zidstoretunnel.sh:1646-1659`. README lama menyebutkan ukuran swap lebih besar (`README.md:20`, `README.md:136`), namun skrip menggunakan 2G. Ketidaksesuaian ini adalah fakta dokumentasi vs implementasi.

## Rujukan Berkas:Baris

| Berkas:Baris | Fungsi |
|---|---|
| `zidstoretunnel.sh:8` | ZIDSTORE_VERSION 1.0.3 |
| `zidstoretunnel.sh:496` | timezone Asia/Jakarta |
| `zidstoretunnel.sh:1153` | Deteksi interface |
| `zidstoretunnel.sh:1163` | PREROUTING UDP 53->5300 |
| `zidstoretunnel.sh:1171-1175` | POSTROUTING 20.8.0.0/24 MASQUERADE |
| `zidstoretunnel.sh:1177-1185` | net.ipv4.ip_forward |
| `zidstoretunnel.sh:1187-1195` | net.core.wmem_max/rmem_max |
| `zidstoretunnel.sh:1198-1202` | iptables-save |
| `zidstoretunnel.sh:1316-1321` | cron xp_all 02:00 |
| `zidstoretunnel.sh:1876-1885` | Prompt reboot interaktif (timeout 60 detik; non-interaktif tanpa reboot) |
| `zidstoretunnel.sh:1369-1373` | cron logclear */6 jam |
| `zidstoretunnel.sh:1375` | restart cron |
| `zidstoretunnel.sh:1646-1659` | swap 2G |
| `README.md:64-68` | Variabel default dokumentasi |
| `README.md:20` | TCP BBR disebutkan |
| `README.md:136` | Swap versi lama disebutkan |
| `VERSION` | 1.0.3 |
| `build.sh:50` | Membaca VERSION |
| `build.sh:134` | Mencetak v${VERSION} |
| `CHANGELOG.md:16` | [1.0.0] |
| `CHANGELOG.md:58-67` | Unreleased |
