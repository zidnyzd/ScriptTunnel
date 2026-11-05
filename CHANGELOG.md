# Changelog

All notable changes to ZidStore Tunnel will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.4] - 2026-11-04

### Added
- r27 (in-place): optimasi kecepatan SlowDNS/DNSTT, biner `dnstt-server` + `dnstt-client` di-upgrade ke jendela KCP 1024 (QueueSize 2048) sehingga throughput menembus plafon lama (A/B terkontrol di jalur nyata: 8 Mbps menjadi 26-30 Mbps; CPU box bukan lagi bottleneck). Klien HTTP Custom memakai `kcpWindow` 512 atau 1024 dengan mode `direct`. Tanpa perubahan skrip installer: box existing menerima biner baru lewat `zidstoretunnel --update --force` (fase SlowDNS mengunduh ulang + verifikasi sha256 terhadap manifest).
- r26 (in-place): optimasi conntrack (nf_conntrack_max 262144 + persist modules-load/modprobe/sysctl; timeout tcp lebih agresif) supaya box dengan banyak user tidak drop paket saat tabel conntrack penuh. Aman live: tanpa reload modul, tanpa flush tabel, tanpa restart service.
- Menu Setting opsi 14 (ON): bila biner dnstt belum ada, menu menawarkan unduh mandiri dengan verifikasi sha256 terhadap manifest, lalu melanjutkan aktivasi (kunci di-generate otomatis bila belum ada).
- Menu Setting: opsi 14 "Turn ON/OFF SlowDNS" untuk menyalakan/mematikan DNSTT dari menu (OFF menulis penanda /etc/slowdns/disabled yang dihormati installer sehingga SlowDNS tidak diaktifkan ulang oleh update berikutnya; ON menghapus penanda, memulihkan domain, menulis ulang routes + unit, lalu mengaktifkan kembali; kunci + biner tetap dipertahankan).
- Verifikasi akhir installer kini toleran terhadap dnstt-server yang sengaja dinonaktifkan (unit disabled/masked tidak lagi menggagalkan update).
- SlowDNS/DNSTT fase 1: biner resmi (bamsoftware) amd64 dari fodder dengan verifikasi sha256, kunci otomatis di /etc/slowdns (server.key 600, server.pub 644), unit dnstt-server dengan forward 127.0.0.1:22 (redirect UDP 53 ke 5300 sudah ada sejak v1.0.3), aktivasi via /etc/slowdns/domain atau env DNSTT_DOMAIN, telemetri slowdns_ready/slowdns_skipped, idempoten untuk upgrade.
- Installer: otomasi subdomain SlowDNS via API saat instalasi (POST /api/slowdns/register, fallback ke-4, fail-open, telemetri source).
- Fitur ubah domain DNSTT via menu (sinkron Cloudflare otomatis; menulis ulang routes.conf dan unit secara konsisten).
- SlowDNS multi-protokol: satu instance multi-route (`-routes-file`) melayani SSH (127.0.0.1:22), vmess (10002), vless (10001), dan trojan (10003) melalui subdomain `vm.`/`vl.`/`tr.` di bawah zona delegasi yang sama, tanpa record Cloudflare tambahan.
- Dukungan klien HTTP Custom v8.0.10 di mode DNS polos: echo payload label pada handshake Noise, kanal kalibrasi `dnstt-calibration/1:`, dan respons 6 tipe record (TXT/NULL/CNAME/NS/MX/SRV). Klien memakai setting payload AUTO dan TLS OFF.
- Kuota data SSH/SlowDNS (daemon `quota-ssh`): penghitungan per akun dari io sesi sshd (rchar+wchar termasuk proses anak relay, dinormalisasi agar setara metrik Xray), peringatan Telegram 90 persen sekali, dan penghapusan akun saat 100 persen (mengikuti perilaku daemon kuota Xray); reset kuota saat renew; prompt kuota di addssh dan renewssh; dukungan parameter kuota di apirenew; berkas di /etc/ssh/quota dan /etc/ssh/usage; tampilan kuota di menu SSH (list member + opsi "12. Set Quota SSH Account") dan checkssh.
- Distribusi domain/pubkey SlowDNS di output akun: SSH (sudah sejak fase 2) dan kini vmess/vless/trojan (termasuk trial) menampilkan domain per protokol + public key di layar dan di file format OpenClash. Respons API pembuatan akun (`apicreate`) juga menyertakan field `slowdns_host` per protokol.
- Hardening unduhan installer: preferensi IPv4 + timeout eksplisit pada semua unduhan jaringan (curl/wget) termasuk jalur update dan fallback fodder.
- Dropbear 2018.76 (build statis dari sumber resmi) kini menjadi DEFAULT saat instalasi dan update: aset fodder `dropbear2018` dengan sha256 terkunci (diverifikasi saat unduh), biner lama dibackup otomatis ke `/usr/local/backup-dropbear`, `apt-mark hold`, idempoten (instalasi yang sudah 2018 tidak disentuh), opt-out `--dropbear=stock` dan paksa `--dropbear=2018`.
- Validasi keterjangkauan UDP 53 saat instalasi baru: port dicek dari luar via `POST /api/checkudp` (echo-listener sementara di dalam VPS, probe dari server API), lalu prompt memilih subdomain SlowDNS (custom, Enter = acak, `-` = tolak, timeout = acak); port tertutup atau ditolak = SlowDNS dilewati tanpa mendaftarkan record NS menggantung. Tanpa TTY, API tidak tersedia, atau python3 tidak ada = perilaku lama (fail-open); mode `--update` tidak berubah.
- Bot Telegram mendukung fitur TRIAL secara bawaan: installer menyinkronkan `api.js` (endpoint `/trialssh`, `/trialvmess`, `/trialvless`, `/trialtrojan`) dan `cleanup_trial_config.py` dari resources dengan verifikasi sha256, membackup api.js lama, memasang cron pembersih konfigurasi trial kedaluwarsa tiap menit, dan me-restart service `api` bila ada perubahan (idempoten, jalan di fresh maupun update; tidak perlu patch manual lagi).
- Reset kuota bulanan bawaan installer: `reset-usage.timer` (setiap tanggal 1 pukul 00:00, `Persistent=true`) kini mereset usage Xray DAN SSH (`/etc/ssh/usage`).
- Backup/Restore: `/root/.vars` (kredensial bot untuk notifikasi dan backup) kini ikut di-backup dan dikembalikan saat restore; biner `dnstt-server` dan `dnstt-client` DIKECUALIKAN dari backup karena installer memasang ulang dengan sha256 terkunci, sehingga ukuran backup kembali kecil dan restore tidak menimpa biner yang lebih baru.

### Changed
- Label versi skrip naik ke V1.0.4 LTS (menu dan ft).

### Fixed
- Deteksi login tunnel Xray: koneksi via websocket maupun DNSTT (yang masuk sebagai 127.0.0.1) kini terdeteksi di `checkvmess`/`checkvless`/`checktrojan` (sebelumnya daftar tampil kosong walau sesi aktif); daftar IP per user dan hitungan log ikut dirapikan.
- Label port BadVPN UDP di output akun (`trialssh`, `apicreate`, `addssh`) dikoreksi menjadi `7100, 7200, 7300`.
- Hitungan kuota SSH: pembacaan io kini mengikuti proses anak relay sshd (privsep), bukan proses monitor, dan dinormalisasi agar setara metrik kuota Xray (sebelumnya trafik data tidak terhitung).
- Backup/Restore kini menyertakan `/etc/slowdns` (kunci server, domain, dan routes DNSTT) agar restore ke VPS baru tidak kehilangan identitas SlowDNS; restore juga toleran terhadap backup lama: komponen yang tidak ada di arsip (mis. SlowDNS/kuota) dilewati dengan catatan `Skipped`, bukan dianggap gagal.
- Restore tidak lagi memunculkan peringatan `/root/.vars` pada lingkungan yang tidak memiliki berkas tersebut.
- Mode upgrade (`zidstoretunnel --update --force`) kini MEMPERTAHANKAN `config.json` Xray pelanggan: unduhan template xray-config dilewati bila konfigurasi sudah ada, sehingga akun vmess/vless/trojan tidak lagi hilang saat update.
- Restore `/etc/slowdns` kini menghentikan `dnstt-server` sementara sebelum menyalin dan menjalankannya kembali setelahnya (tidak ada lagi kegagalan salin akibat berkas biner sedang berjalan).

### Notes
- Kompatibilitas: unit dnstt-server gaya lama (positional domain+target) tetap didukung; VPS pelanggan existing mendapat semua fitur ini otomatis lewat `zidstoretunnel --update --force`.
- Kuota SSH mengikuti konvensi Xray: limit disimpan sebagai byte; nilai 0 atau tanpa berkas berarti unlimited.

## [1.0.3] - 2026-11-03

### Added
- Mode update in-place tanpa instalasi ulang (`--update` unduh + verifikasi, `--upgrade` terapkan, `--force` terapkan ulang versi sama)
- Penanda versi terpasang di `/etc/zidstoretunnel.version`
- Updater mandiri terpasang di `/usr/local/bin/zidstoretunnel` (`sudo zidstoretunnel --update`)
- Guard sertifikat: penerbitan ulang dilewati bila sertifikat masih valid lebih dari 30 hari
- Mode upgrade melewati upgrade paket sistem (`apt upgrade`) dan tidak memaksa reboot

### Security
- Verifikasi checksum SHA256 untuk self-update (`zidstoretunnel` via manifest API)
- Verifikasi checksum SHA256 untuk unduhan eksternal (NodeSource, Xray-install, acme.sh, binary Xray)
- Izin least-privilege untuk direktori dan berkas instalasi (hapus `chmod 777`)
- Kunci lisensi dikirim via header `X-API-Key` dan disimpan `chmod 600` pada `/root/.key`

### Fixed
- Parsing argumen `--key` menangani `--key=NILAI` dan `--key NILAI` dengan validasi format kunci
- Fail-fast tahap kritis (paket dasar, HAProxy, Xray, konfigurasi layanan, unit systemd, start service)
- sshd_config dan common-password diunduh ke berkas sementara lalu diverifikasi sebelum dipasang
- iptables NAT idempoten (cek `-C` sebelum `-A`)
- `mkdir -p` untuk drop-in systemd xray
- Pin mayor npm dan `--ignore-scripts` untuk ekspres/telegraf/axios/moment/sqlite3
- Izin berkas hasil unduhan dinormalisasi 644 sehingga service non-root (ws) dapat membacanya (perbaikan ws.service mode 711 dari mktemp)
- setup_bot memakai biner sqlite3 prebuilt terverifikasi dengan fallback node-gyp modern (kompatibel Python 3.13) dan deteksi kegagalan yang terlihat
- paket python3-setuptools ditambahkan ke daftar dependencies sistem (sabuk pengaman distutils)
- Validasi unduhan diperkuat (penolakan konten HTML/ukuran kecil) + manifest biner fodder
- Cek arsitektur x86_64/amd64 di awal
- Pemeriksaan akhir: ws dan limitquota wajib aktif sebelum instalasi selesai (limitip sengaja dilewati)
- Housekeeping non-destruktif (/etc/shells, /root/.profile, /root/.bashrc, sed UUID)
- install.sh diperbaiki (URL repo benar, mengunduh artefak encoded `zidstoretunnel`, dukungan variabel `KEY` untuk `--key`)
- Kebersihan kode (variabel tak terpakai, `cd` tanpa pengaman, print_rainbow pembagian nol)
- Penyiapan /tmp/ws-ips dengan kepemilikan www-data saat instalasi (mendukung ws.py least-privilege)

### Changed
- Tanpa reboot paksa: cron daily_reboot dihapus; prompt reboot dengan timeout 60 detik, non-interaktif tidak reboot
- Dokumentasi swap diselaraskan ke 2G mengikuti implementasi

### Removed
- OpenVPN dihapus dari stack (sudah tidak diperlukan): paket `openvpn` dan `easy-rsa` dari daftar apt, unduhan + verifikasi + ekstraksi `openvpn.zip`, profil client `client-tcp.ovpn` (1194), `client-udp.ovpn` (2200), `client-ssl.ovpn` (443), fungsi `input_cert_ovpn` + `allovpn.zip`, pengaturan `AUTOSTART`, telemetri `openvpn_ready`, dan aturan iptables MASQUERADE subnet `10.8.0.0/24`. Entri `openvpn.zip` dihapus dari manifest checksums.
- Pembersihan idempoten saat upgrade: stop/disable/mask unit `openvpn@server-tcp`, `openvpn@server-udp`, `openvpn.service`; arsip sisa ke `/root/backup-openvpn-<tanggal>.tar.gz`; hapus `/etc/openvpn` dan berkas `.ovpn` klien; `AUTOSTART="none"`; purge paket `openvpn easy-rsa` (fail-open); telemetri milestone `openvpn_removed`. Instalasi baru tidak menyisakan sisa OpenVPN.
- Port 2200 dihapus dari daftar `-exclude` udp-custom (tidak lagi dipakai OpenVPN).
- Label "SSH OVPN" pada script menu pelanggan diganti menjadi "SSH"; tampilan port/link OpenVPN dihapus dari menu dan pesan akun.

## [1.0.0] - 2024-01-XX

### Added
- Initial release of ZidStore Tunnel (renamed from FighterTunnel ub20)
- Complete VPN/Tunnel installation script for Ubuntu/Debian
- Xray Core support: VMess, VLESS, Trojan, Shadowsocks with WebSocket + gRPC
- OpenVPN support: TCP, UDP, SSL configurations
- SlowDNS (DNSTT) client/server for DNS tunneling
- Python WebSocket proxy (ws.py)
- BadVPN UDP tunneling (ports 7100, 7200, 7300)
- UDP Custom server
- HAProxy load balancing with SSL termination
- Nginx reverse proxy with WebSocket support
- Dropbear lightweight SSH server
- Automatic Let's Encrypt SSL certificates via acme.sh
- Cloudflare DNS integration for SlowDNS NS records
- Systemd service management for all components
- Automatic 5GB swap file creation
- TCP BBR congestion control
- Daily reboot scheduling (05:00)
- Log rotation every 6 hours
- Telegram bot integration (optional)
- Service management script (scripts/manage.sh)
- Configuration templates for all services
- Comprehensive documentation (README.md)

### Changed
- Renamed from "FighterTunnel" to "ZidStore Tunnel"
- Updated branding throughout the script
- Organized configuration files into config/ directory
- Separated systemd service files into systemd/ directory
- Added config.example.sh for easy customization
- Added install.sh wrapper for quick installation
- Improved error handling and logging

### Security
- Disabled UFW and firewalld (using iptables directly)
- Enabled IP forwarding for VPN routing
- Configured secure SSL/TLS ciphers
- Set capability bounding for services
- Added NoNewPrivileges for systemd services

## [Unreleased]

### Planned
- Web-based management dashboard
- Multi-user support with quota management
- Prometheus/Grafana monitoring integration
- Docker deployment support
- Ansible playbook for automated deployment
- IPv6 support
- More protocol options (Hysteria, TUIC, etc.)