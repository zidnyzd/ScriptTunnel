# 08 Operasional SlowDNS (DNSTT)

## Tujuan

Halaman ini mencatat operasional SlowDNS menggunakan DNSTT pada fase 1 v1.0.4: biner, kunci, unit systemd, domain, verifikasi, dan uji konektivitas.

## Arsitektur singkat

- Server: `dnstt-server` di `/etc/slowdns/dnstt-server` (biner resmi bamsoftware rilis 2026-05-01, amd64 statis).
- Listener: UDP `0.0.0.0:5300`.
- Redirect: iptables PREROUTING UDP 53 -> 5300, idempoten sejak v1.0.3.
- Forward: `127.0.0.1:22` (SSH).
- Domain per VPS: `<sub>.zdnstt.web.id` (label pertama domain install), nameserver `ns-<sub>.zdnstt.web.id`. Otomasi Cloudflare aktif via API control plane (`/api/slowdns/register`) sejak fase 2.
- Unit: `/etc/systemd/system/dnstt-server.service`, yang ditulis oleh instalasi bila domain tersedia.
- Telemetri: `slowdns_ready` (aktif), `slowdns_skipped` (dilewati).

## Status aktivasi

Installer mengaktifkan SlowDNS secara otomatis bila domain tersedia. Prioritas domain:

1. Unit `dnstt-server.service` yang sudah ada (membaca `ExecStart`).
2. `/etc/slowdns/domain`.
3. Environment `DNSTT_DOMAIN`.
4. Otomatis via API control plane: POST /api/slowdns/register dengan header X-API-Key, dipakai bila unit existing, `/etc/slowdns/domain`, dan env `DNSTT_DOMAIN` semuanya tidak ada.

Bila tidak ada domain valid, blok SlowDNS dilewati (fail-open). Unit `dnstt-client` tidak dipasang; biner `dnstt-client` tersedia di `/etc/slowdns` untuk keperluan uji. Hasil domain API ditulis ke `/etc/slowdns/domain`.

## Kunci

- `/etc/slowdns/server.key` (mode 600).
- `/etc/slowdns/server.pub` (mode 644).
- Kunci dihasilkan dengan `-gen-key` bila belum ada; idempoten (tidak di-regenerate pada re-run).
- Bagikan pubkey ke pelanggan. Pubkey dirancang dibagikan; jangan bagikan private key.

## Prosedur rotasi kunci

1. Jalankan `-gen-key` untuk menghasilkan kunci baru di berkas baru.
2. Pasang kunci baru: ganti `/etc/slowdns/server.key` dan `server.pub`.
3. Restart unit: `systemctl restart dnstt-server`.
4. Bagikan pubkey baru ke pelanggan.
5. Pelanggan lama yang masih memakai pubkey lama harus memperbarui konfigurasi. Instalasi/upgrade berikutnya tidak meregenerasi kunci selama pasangan kunci masih ada.

## Verifikasi cepat

- `systemctl status dnstt-server`
- `ss -ulnp | grep 5300`
- `iptables -t nat -S PREROUTING | grep 5300`
- `journalctl -u dnstt-server`

## Uji konektivitas

Contoh perintah `dnstt-client`:

```
/etc/slowdns/dnstt-client -udp <ip-server>:5300 --pubkey-file /etc/slowdns/server.pub <domain> 127.0.0.1:PORT
/etc/slowdns/dnstt-client -doh https://cloudflare-dns.com/dns-query --pubkey-file /etc/slowdns/server.pub <domain> 127.0.0.1:PORT
```

Catatan penting:

- Kirim byte dulu sebelum membaca; koneksi yang hanya membaca tanpa mengirim tidak menerima data sampai byte pertama dikirim.
- Query polos ke domain tunnel dijawab `NXDOMAIN` oleh `dnstt-server`; ini NORMAL, bukan kerusakan.
- Klien DoH bergantung pada ketersediaan endpoint Cloudflare.

## Menetapkan atau mengubah domain

Fitur ini kini tersedia di menu System Settings, item "9. Change SlowDNS domain" (berkas menusetting).

1. Masukkan subdomain baru. Subdomain divalidasi: huruf kecil, angka, tanda hubung, maksimal 63 karakter, dan tidak boleh diawali `ns-`.
2. Sistem menyinkronkan record Cloudflare secara otomatis lewat API (POST /api/slowdns/register).
3. Domain hasil sinkronisasi ditulis ke `/etc/slowdns/domain` dan `/etc/xray/dns`.
4. Unit `dnstt-server` ditulis ulang dengan domain baru lalu di-restart.
5. Bila API membalas error terstruktur (mis. subdomain sudah dipakai pemilik lain, `sub_taken`), perubahan dibatalkan tanpa mengubah apa pun; pilih subdomain lain.
6. Bila API tidak memberi respons (gangguan jaringan), domain turunan tetap dipakai dengan peringatan (fail-open).
7. Record DNS lama tidak dihapus otomatis, melainkan ditampilkan sebagai catatan agar operator bisa membersihkannya sendiri bila perlu.

## Troubleshooting

Lihat `07-jebakan-dan-troubleshooting.md` untuk entri SlowDNS (delegasi NS, propagasi, NXDOMAIN normal, dan nuansa kirim byte dulu).

## Telemetri

- `slowdns_ready`: aktivasi berhasil, bersama domain. Kini menambah field "source" (unit/file/env/api) yang menandakan sumber domain.
- `slowdns_skipped`: domain tidak tersedia atau unduhan/verifikasi gagal; instalasi tetap lanjut.

## Rujukan kode

- `zidstoretunnel.sh:1693-1790`: blok SlowDNS/DNSTT fase 1 (biner, kunci, domain, unit, telemetri, fail-open).
- `systemd/dnstt-server.service`: template unit, lakukan modifikasi di dalam repo (installer menulis unit di `/etc/systemd/system`).
- `/etc/slowdns/*`: biner dan kunci di server target.
