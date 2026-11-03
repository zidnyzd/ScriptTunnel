# 07 Jebakan dan Troubleshooting

## Format Entri

Setiap entri berisi:
- Gejala: yang diamati di server.
- Penyebab Teknis: penyebab yang bisa diverifikasi dari kode.
- Cara Menghindari atau Mengatasi: langkah teknis.

## Entri 1: Validasi Lisensi Gagal Saat IP Mismatch atau API Offline

Gejala: Pesan `License validation failed: ...` muncul dan skrip keluar sebelum instalasi dimulai.

Penyebab Teknis: `zidstoretunnel.sh:298-306` mengambil IP VPS dari `ipinfo.io/ip`, lalu memvalidasi kunci lewat header `X-API-Key` ke `ZIDSTORE_API_URL/api/key` (bukan parameter query). Jika respon kosong atau dimulai dengan `Error`, skrip keluar. Setelah validasi berhasil, skrip mengunduh manifest `resources/checksums.txt` (`zidstoretunnel.sh:313-326`) dan memeriksa integritas unduhan dengan fungsi `verify_sha256` (`zidstoretunnel.sh:327-336`) sebelum eksekusi. Kunci dan IP disimpan ke variabel `key` dan `ip`, namun jika validasi gagal, skrip tidak melanjutkan. Validasi juga bergantung pada ketersediaan `zds.web.id` yang didefinisikan di `zidstoretunnel.sh:10`.

Cara Menghindari:
- Pastikan `INSTALL_KEY` benar dan didapat dari `https://t.me/zidstoretunnel` (`zidstoretunnel.sh:279`).
- Pastikan VPS memiliki akses internet ke `zds.web.id`.
- Pastikan IP publik VPS sesuai dengan yang didaftarkan ke lisensi.
- Jika API offline, tunggu atau hubungi admin.

## Entri 2: Port 80/443 Konflik Antara Nginx, Apache, atau HAProxy Bawaan

Gejala: HAProxy gagal start dengan error `Address already in use` atau Nginx gagal start karena port 80/443 sudah dipakai.

Penyebab Teknis: HAProxy mengikat port 80 dan 443 (`config/haproxy/haproxy.cfg:44`, `config/haproxy/haproxy.cfg:66`). Nginx juga mengikat port 80 dan 443 (`config/nginx/xray.conf:3`, `config/nginx/xray.conf:11`). Jika Apache terinstal, skrip menghapusnya (`zidstoretunnel.sh:1074-1079`), namun jika ada layanan lain yang mengikat port 80/443 sebelum skrip dijalankan, konflik akan terjadi. Skrip juga menghentikan HAProxy dan Nginx sebelum setup SSL (`zidstoretunnel.sh:1258-1261`), namun tidak memeriksa port lain.

Cara Menghindari:
- Hapus service yang mengikat port 80/443 sebelum instalasi: `systemctl stop apache2` atau `systemctl stop nginx` manual.
- Verifikasi dengan `ss -tulpn | grep -E ':80|:443'` sebelum menjalankan installer.
- Skrip sendiri menghapus Apache (`zidstoretunnel.sh:1074-1079`), tetapi tidak menghapus Nginx versi lama dari repo default jika sudah terpasang.

## Entri 3: Penerbitan Sertifikat SSL acme.sh Timeout atau Gagal Validasi Domain

Gejala: `/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256` gagal dengan error timeout atau validasi DNS.

Penyebab Teknis: Skrip menjalankan `acme.sh` dalam mode `--standalone` (`zidstoretunnel.sh:1291`), yang memerlukan port 80 bebas selama penerbitan. Jika port 80 masih dipakai oleh Nginx atau layanan lain, validasi gagal. Skrip juga mengupgrade acme.sh dan mengatur default CA ke Let's Encrypt sebelum issue (`zidstoretunnel.sh:1282-1283`). Jika domain tidak resolve ke IP VPS, validasi DNS juga gagal. Skrip memverifikasi DNS A record sebelum instalasi (`zidstoretunnel.sh:439-464`), namun verifikasi hanya dilakukan sekali di awal.

Cara Menghindari:
- Pastikan domain resolve ke IP VPS sebelum instalasi (`zidstoretunnel.sh:439-464`).
- Pastikan port 80 bebas sebelum acme.sh dijalankan. Skrip menghentikan haproxy dan nginx (`zidstoretunnel.sh:1258-1261`), tetapi layanan lain mungkin masih aktif.
- Jika gagal, jalankan ulang perintah acme.sh secara manual setelah memastikan port 80 bebas.
- Sertifikat disimpan ke `/etc/xray/xray.crt` dan `/etc/xray/xray.key` (`zidstoretunnel.sh:1292`), lalu digabungkan menjadi `/etc/haproxy/yha.pem` (`zidstoretunnel.sh:1294`).

## Entri 4: SlowDNS Tidak Merespons karena Delegasi NS Cloudflare Belum Propagasi

Gejala: Koneksi SlowDNS tidak berfungsi, query DNS ke NS domain tidak diarahkan ke server.

Penyebab Teknis: SlowDNS memerlukan delegasi NS Cloudflare ke `domain_ns` (default `dnstt.me`, `README.md:64`). DNSTT server berjalan di port 5300 dengan redirect PREROUTING (`zidstoretunnel.sh:1161`, `systemd/dnstt-server.service:12`). Jika delegasi NS belum propagasi, query tidak sampai ke server. Client DNSTT mengirim DoH ke Cloudflare (`systemd/dnstt-client.service:12`), sehingga koneksi client bergantung pada ketersediaan DoH endpoint.

Cara Menghindari:
- Verifikasi delegasi NS di Cloudflare sebelum mengandalkan SlowDNS.
- Tunggu propagasi DNS (biasanya beberapa menit hingga jam).
- Verifikasi dengan `dig @ns1.cloudflare.com domain_ns NS` atau tool DNS lain.
- Pastikan `dnstt-server` unit aktif: `systemctl status dnstt-server` (`systemd/dnstt-server.service`).

## Entri 5: Dropbear atau SSH Terkunci Setelah Perubahan Konfigurasi Firewall

Gejala: Tidak bisa login SSH setelah instalasi selesai, atau Dropbear tidak merespons.

Penyebab Teknis: Skrip menghapus unit dropbear bawaan dan menggantinya dengan SysV init (`zidstoretunnel.sh:1429-1431`), lalu menjalankan `/etc/init.d/dropbear start` dan `restart` (`zidstoretunnel.sh:1434-1435`). Konfigurasi Dropbear diunduh dari server API (`zidstoretunnel.sh:975-990`). Skrip juga menulis ulang `/etc/ssh/sshd_config` (`zidstoretunnel.sh:992-1021`). Jika konfigurasi SSH yang diunduh membatasi port atau pengguna, akses bisa terkunci. Selain itu, skrip menghapus `ufw` dan `firewalld` (`zidstoretunnel.sh:583-601`), tetapi tidak menambahkan aturan iptables untuk membatasi akses SSH; aturan yang ada hanya untuk DNS dan NAT VPN (`zidstoretunnel.sh:1160-1173`).

Cara Menghindari:
- Pastikan akses SSH melalui port 22 tetap terbuka sebelum mengubah konfigurasi.
- Jika terkunci, gunakan console VPS (VNC/serial) untuk memperbaiki.
- Verifikasi konfigurasi sshd dengan `sshd -t` sebelum restart (`zidstoretunnel.sh:992-1014`).
- Pastikan Dropbear berjalan: `/etc/init.d/dropbear status` atau `systemctl status dropbear` (jika unit terpasang).

## Entri 6: Swap Size Tidak Sesuai Dokumentasi

Gejala: Server memiliki swap 2G, sesuai v1.0.3.

Penyebab Teknis: v1.0.3 menetapkan `swap_size="2G"` (`zidstoretunnel.sh:1643-1657`) secara konsisten. Referensi README yang masih menyebutkan ukuran swap lebih besar merupakan sisa versi lama sebelum sinkronisasi dokumentasi. Dokumentasi v1.0.3 sudah diselaraskan ke 2G.

Cara Menghindari:
- Default 2G sudah sesuai spesifikasi v1.0.3. Jika perlu lebih besar, ubah `zidstoretunnel.sh:1643-1657` sebelum build.
- Atau buat swap tambahan secara manual setelah instalasi.

## Entri 7: Xray gRPC Tidak Tersedia di Konfigurasi Repo

Gejala: README dan CHANGELOG menyebut dukungan gRPC, tetapi konfigurasi Xray yang ada hanya menggunakan WebSocket.

Penyebab Teknis: Seluruh konfigurasi Xray di repo menggunakan `network: "ws"` (`config/xray/vmess.json:21`, `config/xray/vless.json:21`, `config/xray/trojan.json:20`, `config/xray/shadowsocks.json:22`). Tidak ada `grpcSettings` di salah satu berkas. Klaim gRPC berasal dari dokumentasi, bukan dari template lokal. HAProxy juga memiliki blok frontend TCP opsional yang ter-comment (`config/haproxy/haproxy.cfg:83-118`), yang bisa dipakai untuk gRPC, namun tidak aktif secara default.

Cara Menghindari:
- Jangan mengandalkan gRPC kecuali konfigurasi diubah secara eksplisit.
- Jika gRPC diperlukan, tambahkan inbound gRPC di konfigurasi Xray dan aktifkan frontend TCP yang sesuai di HAProxy.

## Entri 8: Nginx Rate Limiting Dapat Mengganggu Traffic Tinggi

Gejala: Koneksi sering terputus atau error 503 saat traffic tinggi.

Penyebab Teknis: Nginx mengonfigurasi rate limiting zone `api` pada 10r/s dan `login` pada 5r/m (`config/nginx/nginx.conf:34-35`). Jika zone ini diterapkan ke location yang melayani traffic tinggi, koneksi bisa dibatasi. Namun, zone ini didefinisikan tetapi tidak diterapkan secara eksplisit di `config/nginx/xray.conf` (tidak ada `limit_req` directive). Jadi ini adalah potensi, bukan masalah aktif.

Cara Menghindari:
- Verifikasi tidak ada `limit_req` yang diterapkan pada location WebSocket.
- Jika perlu, sesuaikan rate limit di `config/nginx/nginx.conf:34-35`.

## Entri 9: Node.js Versi 22 Mungkin Tidak Kompatibel dengan VPS Lama

Gejala: Instalasi Node.js gagal pada OS lama yang tidak mendukung NodeSource 22.x.

Penyebab Teknis: Skrip mengunduh setup NodeSource 22.x (`zidstoretunnel.sh:706`). OS yang didukung adalah Ubuntu 18.04/20.04/22.04/24.04 dan Debian 10/11/12/13 (`README.md:24`). Node.js 22.x mungkin tidak mendukung Ubuntu 18.04 atau Debian 10. Skrip tidak memeriksa kompatibilitas Node.js dengan OS.

Cara Menghindari:
- Gunakan OS yang masih mendukung Node.js 22.x (Ubuntu 20.04 ke atas, Debian 11 ke atas).
- Atau ubah `zidstoretunnel.sh:706` untuk menggunakan versi NodeSource yang lebih lama.

## Entri 10: Tidak Ada Verifikasi Integritas pada Berkas yang Diunduh

Gejala: Skrip mengunduh banyak berkas dari API server tanpa verifikasi hash atau tanda tangan.

Penyebab Teknis: Sejak v1.0.3, biner fodder kritis (udp-custom-linux-amd64, badvpn, openvpn.zip, src.zip, bot.zip) diverifikasi terhadap manifest `checksums.txt` melalui `verify_if_listed` (`zidstoretunnel.sh:339-354`). Untuk berkas lain, heuristik penolakan konten HTML dan ukuran minimum tetap dipakai, sehingga berkas teks valid masih dapat ditolak (contoh `zidstoretunnel.sh:947`).

Cara Menghindari:
- Verifikasi berkas yang diunduh secara manual jika diperlukan.
- Jangan menjalankan skrip dari sumber yang tidak tepercaya.
- Pastikan manifest `checksums.txt` di server API selalu sinkron dengan artefak yang beredar; perbarui melalui `scripts/gen_checksums.sh` dan unggah ke `/www/ZidStoreAPI/resources/checksums.txt`.

## Entri 11: Instalasi Berhenti pada Pesan Verifikasi Checksum Gagal atau Gagal Mengunduh Manifest

Gejala: Instalasi berhenti dengan pesan `Verifikasi checksum gagal untuk <nama>` (misalnya `setup_22.x`, `xray-install.sh`, `acme-install.sh`, `xray.linux.64bit`) atau `Gagal mengunduh manifest checksum. Instalasi dihentikan.`

Penyebab Teknis: Skrip mengunduh manifest `checksums.txt` dari `${ZIDSTORE_API_URL}/resources/checksums.txt` (`zidstoretunnel.sh:313-320`) dan memverifikasi setiap artefak dengan fungsi `verify_sha256` (`zidstoretunnel.sh:327-336`). Jika manifest tidak ada atau tidak diunduh, skrip keluar (fail closed). Jika hash di manifest tidak cocok dengan hash artefak yang diunduh (misalnya upstream berubah tanpa perbarui manifest), skrip juga keluar. Kegagalan ini bisa terjadi karena server API tidak terjangkau atau manifest sudah tidak sinkron dengan artefak yang beredar.

Cara Menghindari atau Mengatasi:
- Jalankan `scripts/gen_checksums.sh` di mesin rilis untuk menghasilkan manifest baru yang mencakup semua artefak yang beredar.
- Unggah hasil ke `/www/ZidStoreAPI/resources/checksums.txt` di server API.
- Ulangi instalasi setelah manifest diperbarui.
- Jika server API tidak terjangkau, periksa ketersediaan jaringan dan kembali coba; atau hubungi admin.

## Entri 12: Instalasi Gagal, Baca Log Lokal dan Timeline Telemetri

Gejala: Instalasi gagal dan pelanggan tidak tahu fase mana yang bermasalah.

Penyebab Teknis: v1.0.3 selalu menulis log lokal ke `/var/log/zidstoretunnel-install.log` dengan rotasi otomatis ke `.1` saat ukuran melebihi 5MB (`zidstoretunnel.sh:235-239`). Instalasi juga mengirim event progres fail-open ke server (`POST /api/install-logs`, timeout 5 detik, tanpa `jq`, tidak pernah menggagalkan instalasi) dan mencetak `Install ID` di akhir (`zidstoretunnel.sh:193-214` dan `zidstoretunnel.sh:1769`). Sisi server, admin mengakses timeline lewat command bot `/installlog <ip|install_id>` dan membersihkan entri >30 hari melalui `/installlog prune` (retensi 30 hari, pruning otomatis tiap 24 jam).

Cara Menghindari atau Mengatasi:
- Minta Install ID pelanggan, lalu jalankan `/installlog <install_id>` pada command bot.
- Baca event terakhir dengan `status=failed`; nilai `step` menunjukkan fase instalasi terakhir.
- Eksekusi `tail` pada log lokal di server pelanggan untuk mendapatkan error konkret.
- Admin dapat menjalankan `/installlog prune` untuk menghapus entri lebih dari 30 hari sesuai retensi.

## Rujukan Berkas:Baris

| Berkas:Baris | Fungsi |
|---|---|
| `zidstoretunnel.sh:10` | ZIDSTORE_API_URL |
| `zidstoretunnel.sh:265-295` | Validasi INSTALL_KEY kosong |
| `zidstoretunnel.sh:298-306` | Validasi lisensi IP |
| `zidstoretunnel.sh:439-464` | Verifikasi DNS A record |
| `zidstoretunnel.sh:583-601` | Hapus ufw dan firewalld |
| `zidstoretunnel.sh:706` | NodeSource 22.x |
| `zidstoretunnel.sh:879-924` | download_file |
| `zidstoretunnel.sh:926-961` | zid_download |
| `zidstoretunnel.sh:975-990` | Unduh dropbear |
| `zidstoretunnel.sh:992-1021` | Unduh sshd_config |
| `zidstoretunnel.sh:1074-1079` | Hapus Apache |
| `zidstoretunnel.sh:1161` | PREROUTING UDP 53->5300 |
| `zidstoretunnel.sh:1258-1261` | Hentikan haproxy dan nginx |
| `zidstoretunnel.sh:1291` | acme.sh --issue |
| `zidstoretunnel.sh:1292` | acme.sh --installcert |
| `zidstoretunnel.sh:1294` | Gabung yha.pem |
| `zidstoretunnel.sh:1429-1431` | Hapus unit dropbear |
| `zidstoretunnel.sh:1434-1435` | Start dropbear |
| `zidstoretunnel.sh:1645` | swap_size 2G |
| `config/haproxy/haproxy.cfg:44` | Bind 443 |
| `config/haproxy/haproxy.cfg:66` | Bind 80 |
| `config/nginx/nginx.conf:34-35` | Rate limit zone |
| `config/nginx/xray.conf:3` | Listen 80 |
| `config/nginx/xray.conf:11` | Listen 443 |
| `config/xray/vmess.json:21` | network ws |
| `config/xray/vless.json:21` | network ws |
| `config/xray/trojan.json:20` | network ws |
| `config/xray/shadowsocks.json:22` | network ws |
| `systemd/dnstt-server.service:12` | DNSTT server port 5300 |
| `systemd/dnstt-client.service:12` | DNSTT client DoH |
| `zidstoretunnel.sh:235-239` | Log lokal instalasi dan rotasi otomatis >5MB ke .1 |
| `zidstoretunnel.sh:193-214` | Event progres telemetri ke POST /api/install-logs (fail-open) |
| `README.md:20` | TCP BBR |
| `README.md:64` | domain_ns default |
| `README.md:68` | swap_size 2G (dokumentasi lama ukuran lebih besar) |

## Entri 13: Update ke Versi Terbaru Tanpa Instalasi Ulang

Gejala: VPS yang sudah terpasang perlu naik versi tanpa menjalankan instalasi ulang.

Solusi:
- Jalankan `sudo zidstoretunnel --update`: skrip mengunduh versi terbaru, memverifikasi checksum terhadap manifest server (`zidstoretunnel.sh:90-119`), lalu menerapkan upgrade di tempat.
- Bila perintah belum tersedia (instalasi sebelum v1.0.3): `curl -sL https://zds.web.id/?key=$(cat /root/.key) | sudo bash -s -- --update`.
- `--upgrade` menerapkan berkas yang ada di server; `--force` menerapkan ulang walau versi sama. Bila sudah versi terbaru tanpa `--force`, skrip berhenti dengan pesan jelas sebelum menyentuh layanan (`zidstoretunnel.sh:140-163`).
- Saat upgrade: kunci dibaca dari `/root/.key`, domain dari `/etc/xray/domain`, sertifikat tidak diterbitkan ulang bila masih valid lebih dari 30 hari (`zidstoretunnel.sh:1285-1293`), upgrade paket sistem dilewati (`zidstoretunnel.sh:626-639`), dan tidak ada reboot paksa.
- Sejak v1.0.3 (revisi ini), mode upgrade juga membersihkan sisa OpenVPN: stop/disable/mask unit, arsip `/root/backup-openvpn-<tanggal>.tar.gz`, hapus `/etc/openvpn`, purge paket openvpn/easy-rsa; tercatat sebagai milestone telemetri `openvpn_removed`.
- Versi terpasang tercatat di `/etc/zidstoretunnel.version` (`zidstoretunnel.sh:1736-1740`); updater mandiri dipasang di `/usr/local/bin/zidstoretunnel` (`zidstoretunnel.sh:1742-1754`).

Cara Menghindari:
- Jalankan update saat trafik rendah; layanan direstart dan diverifikasi otomatis oleh skrip.
- Komponen baru pada rilis mendatang ikut terpasang otomatis karena blok komponen dijalankan ulang secara idempoten.
