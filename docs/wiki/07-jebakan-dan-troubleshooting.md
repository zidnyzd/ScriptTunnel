# 07 Jebakan dan Troubleshooting

## Format Entri

Setiap entri berisi:
- Gejala: yang diamati di server.
- Penyebab Teknis: penyebab yang bisa diverifikasi dari kode.
- Cara Menghindari atau Mengatasi: langkah teknis.

## Entri 1: Validasi Lisensi Gagal Saat IP Mismatch atau API Offline

Gejala: Pesan `License validation failed: ...` muncul dan skrip keluar sebelum instalasi dimulai.

Penyebab Teknis: `zidstoretunnel.sh:68-75` mengambil IP VPS dari `ipinfo.io/ip`, lalu memanggil `ZIDSTORE_API_URL/api/key?key=INSTALL_KEY`. Jika respon kosong atau dimulai dengan `Error`, skrip keluar. Kunci dan IP disimpan ke variabel `key` dan `ip`, namun jika validasi gagal, skrip tidak melanjutkan. Validasi juga bergantung pada ketersediaan `zds.web.id` yang didefinisikan di `zidstoretunnel.sh:10`.

Cara Menghindari:
- Pastikan `INSTALL_KEY` benar dan didapat dari `https://t.me/zidstoretunnel` (`zidstoretunnel.sh:63`).
- Pastikan VPS memiliki akses internet ke `zds.web.id`.
- Pastikan IP publik VPS sesuai dengan yang didaftarkan ke lisensi.
- Jika API offline, tunggu atau hubungi admin.

## Entri 2: Port 80/443 Konflik Antara Nginx, Apache, atau HAProxy Bawaan

Gejala: HAProxy gagal start dengan error `Address already in use` atau Nginx gagal start karena port 80/443 sudah dipakai.

Penyebab Teknis: HAProxy mengikat port 80 dan 443 (`config/haproxy/haproxy.cfg:42`, `config/haproxy/haproxy.cfg:64`). Nginx juga mengikat port 80 dan 443 (`config/nginx/xray.conf:3`, `config/nginx/xray.conf:11`). Jika Apache terinstal, skrip menghapusnya (`zidstoretunnel.sh:671-676`), namun jika ada layanan lain yang mengikat port 80/443 sebelum skrip dijalankan, konflik akan terjadi. Skrip juga menghentikan HAProxy dan Nginx sebelum setup SSL (`zidstoretunnel.sh:809-812`), namun tidak memeriksa port lain.

Cara Menghindari:
- Hapus service yang mengikat port 80/443 sebelum instalasi: `systemctl stop apache2` atau `systemctl stop nginx` manual.
- Verifikasi dengan `ss -tulpn | grep -E ':80|:443'` sebelum menjalankan installer.
- Skrip sendiri menghapus Apache (`zidstoretunnel.sh:671-676`), tetapi tidak menghapus Nginx versi lama dari repo default jika sudah terpasang.

## Entri 3: Penerbitan Sertifikat SSL acme.sh Timeout atau Gagal Validasi Domain

Gejala: `/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256` gagal dengan error timeout atau validasi DNS.

Penyebab Teknis: Skrip menjalankan `acme.sh` dalam mode `--standalone` (`zidstoretunnel.sh:821`), yang memerlukan port 80 bebas selama penerbitan. Jika port 80 masih dipakai oleh Nginx atau layanan lain, validasi gagal. Skrip juga mengupgrade acme.sh dan mengatur default CA ke Let's Encrypt sebelum issue (`zidstoretunnel.sh:819-820`). Jika domain tidak resolve ke IP VPS, validasi DNS juga gagal. Skrip memverifikasi DNS A record sebelum instalasi (`zidstoretunnel.sh:130-136`), namun verifikasi hanya dilakukan sekali di awal.

Cara Menghindari:
- Pastikan domain resolve ke IP VPS sebelum instalasi (`zidstoretunnel.sh:130-136`).
- Pastikan port 80 bebas sebelum acme.sh dijalankan. Skrip menghentikan haproxy dan nginx (`zidstoretunnel.sh:809-812`), tetapi layanan lain mungkin masih aktif.
- Jika gagal, jalankan ulang perintah acme.sh secara manual setelah memastikan port 80 bebas.
- Sertifikat disimpan ke `/etc/xray/xray.crt` dan `/etc/xray/xray.key` (`zidstoretunnel.sh:822`), lalu digabungkan menjadi `/etc/haproxy/yha.pem` (`zidstoretunnel.sh:823`).

## Entri 4: SlowDNS Tidak Merespons karena Delegasi NS Cloudflare Belum Propagasi

Gejala: Koneksi SlowDNS tidak berfungsi, query DNS ke NS domain tidak diarahkan ke server.

Penyebab Teknis: SlowDNS memerlukan delegasi NS Cloudflare ke `domain_ns` (default `dnstt.me`, `README.md:64`). DNSTT server berjalan di port 5300 dengan redirect PREROUTING (`zidstoretunnel.sh:744`, `systemd/dnstt-server.service:12`). Jika delegasi NS belum propagasi, query tidak sampai ke server. Client DNSTT mengirim DoH ke Cloudflare (`systemd/dnstt-client.service:12`), sehingga koneksi client bergantung pada ketersediaan DoH endpoint.

Cara Menghindari:
- Verifikasi delegasi NS di Cloudflare sebelum mengandalkan SlowDNS.
- Tunggu propagasi DNS (biasanya beberapa menit hingga jam).
- Verifikasi dengan `dig @ns1.cloudflare.com domain_ns NS` atau tool DNS lain.
- Pastikan `dnstt-server` unit aktif: `systemctl status dnstt-server` (`systemd/dnstt-server.service`).

## Entri 5: Dropbear atau SSH Terkunci Setelah Perubahan Konfigurasi Firewall

Gejala: Tidak bisa login SSH setelah instalasi selesai, atau Dropbear tidak merespons.

Penyebab Teknis: Skrip menghapus unit dropbear bawaan dan menggantinya dengan SysV init (`zidstoretunnel.sh:1078-1080`), lalu menjalankan `/etc/init.d/dropbear start` dan `restart` (`zidstoretunnel.sh:1083-1084`). Konfigurasi Dropbear diunduh dari server API (`zidstoretunnel.sh:594-609`). Skrip juga menulis ulang `/etc/ssh/sshd_config` (`zidstoretunnel.sh:611-621`). Jika konfigurasi SSH yang diunduh membatasi port atau pengguna, akses bisa terkunci. Selain itu, skrip menghapus `ufw` dan `firewalld` (`zidstoretunnel.sh:258-276`), tetapi tidak menambahkan aturan iptables untuk membatasi akses SSH; aturan yang ada hanya untuk DNS dan NAT VPN (`zidstoretunnel.sh:743-760`).

Cara Menghindari:
- Pastikan akses SSH melalui port 22 tetap terbuka sebelum mengubah konfigurasi.
- Jika terkunci, gunakan console VPS (VNC/serial) untuk memperbaiki.
- Verifikasi konfigurasi sshd dengan `sshd -t` sebelum restart (`zidstoretunnel.sh:615-617`).
- Pastikan Dropbear berjalan: `/etc/init.d/dropbear status` atau `systemctl status dropbear` (jika unit terpasang).

## Entri 6: Swap Size Tidak Sesuai Dokumentasi

Gejala: Server memiliki swap 2G, bukan 5G seperti yang disebutkan di README.

Penyebab Teknis: README menyebutkan `swap_size` default 5G (`README.md:68`, `README.md:20`, `README.md:136`), tetapi `zidstoretunnel.sh:1223` mendefinisikan `swap_size="2G"`. Ini adalah ketidaksesuaian antara dokumentasi dan implementasi.

Cara Menghindari:
- Jika ingin 5G, ubah `zidstoretunnel.sh:1223` menjadi `swap_size="5G"` sebelum build.
- Atau buat swap tambahan secara manual setelah instalasi.

## Entri 7: Xray gRPC Tidak Tersedia di Konfigurasi Repo

Gejala: README dan CHANGELOG menyebut dukungan gRPC, tetapi konfigurasi Xray yang ada hanya menggunakan WebSocket.

Penyebab Teknis: Seluruh konfigurasi Xray di repo menggunakan `network: "ws"` (`config/xray/vmess.json:21`, `config/xray/vless.json:21`, `config/xray/trojan.json:20`, `config/xray/shadowsocks.json:22`). Tidak ada `grpcSettings` di salah satu berkas. Klaim gRPC berasal dari dokumentasi, bukan dari template lokal. HAProxy juga memiliki blok frontend TCP opsional yang ter-comment (`config/haproxy/haproxy.cfg:81-116`), yang bisa dipakai untuk gRPC, namun tidak aktif secara default.

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

Penyebab Teknis: Skrip mengunduh setup NodeSource 22.x (`zidstoretunnel.sh:366`). OS yang didukung adalah Ubuntu 18.04/20.04/22.04/24.04 dan Debian 10/11/12/13 (`README.md:24`). Node.js 22.x mungkin tidak mendukung Ubuntu 18.04 atau Debian 10. Skrip tidak memeriksa kompatibilitas Node.js dengan OS.

Cara Menghindari:
- Gunakan OS yang masih mendukung Node.js 22.x (Ubuntu 20.04 ke atas, Debian 11 ke atas).
- Atau ubah `zidstoretunnel.sh:366` untuk menggunakan versi NodeSource yang lebih lama.

## Entri 10: Tidak Ada Verifikasi Integritas pada Berkas yang Diunduh

Gejala: Skrip mengunduh banyak berkas dari API server tanpa verifikasi hash atau tanda tangan.

Penyebab Teknis: Fungsi `download_file` (`zidstoretunnel.sh:510-550`) dan `zid_download` (`zidstoretunnel.sh:552-582`) hanya memeriksa ukuran berkas (>100 byte atau >1000 byte) dan tipe berkas, tetapi tidak memverifikasi hash. Selain itu, `zid_download` memeriksa `ftype` tidak mengandung "HTML" atau "text" (`zidstoretunnel.sh:570`), yang bisa menolak berkas teks yang valid.

Cara Menghindari:
- Verifikasi berkas yang diunduh secara manual jika diperlukan.
- Jangan menjalankan skrip dari sumber yang tidak tepercaya.

## Rujukan Berkas:Baris

| Berkas:Baris | Fungsi |
|---|---|
| `zidstoretunnel.sh:10` | ZIDSTORE_API_URL |
| `zidstoretunnel.sh:60-65` | Validasi INSTALL_KEY kosong |
| `zidstoretunnel.sh:68-75` | Validasi lisensi IP |
| `zidstoretunnel.sh:130-136` | Verifikasi DNS A record |
| `zidstoretunnel.sh:258-276` | Hapus ufw dan firewalld |
| `zidstoretunnel.sh:366` | NodeSource 22.x |
| `zidstoretunnel.sh:510-550` | download_file |
| `zidstoretunnel.sh:552-582` | zid_download |
| `zidstoretunnel.sh:594-609` | Unduh dropbear |
| `zidstoretunnel.sh:611-621` | Unduh sshd_config |
| `zidstoretunnel.sh:671-676` | Hapus Apache |
| `zidstoretunnel.sh:744` | PREROUTING UDP 53->5300 |
| `zidstoretunnel.sh:809-812` | Hentikan haproxy dan nginx |
| `zidstoretunnel.sh:821` | acme.sh --issue |
| `zidstoretunnel.sh:822` | acme.sh --installcert |
| `zidstoretunnel.sh:823` | Gabung yha.pem |
| `zidstoretunnel.sh:1078-1080` | Hapus unit dropbear |
| `zidstoretunnel.sh:1083-1084` | Start dropbear |
| `zidstoretunnel.sh:1223` | swap_size 2G |
| `config/haproxy/haproxy.cfg:42` | Bind 443 |
| `config/haproxy/haproxy.cfg:64` | Bind 80 |
| `config/nginx/nginx.conf:34-35` | Rate limit zone |
| `config/nginx/xray.conf:3` | Listen 80 |
| `config/nginx/xray.conf:11` | Listen 443 |
| `config/xray/vmess.json:21` | network ws |
| `config/xray/vless.json:21` | network ws |
| `config/xray/trojan.json:20` | network ws |
| `config/xray/shadowsocks.json:22` | network ws |
| `systemd/dnstt-server.service:12` | DNSTT server port 5300 |
| `systemd/dnstt-client.service:12` | DNSTT client DoH |
| `README.md:20` | TCP BBR |
| `README.md:64` | domain_ns default |
| `README.md:68` | swap_size 5G |
