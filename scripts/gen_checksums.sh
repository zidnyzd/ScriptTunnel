#!/usr/bin/env bash
# gen_checksums.sh - Generator manifest checksums.txt untuk ZidStore Tunnel
#
# Kegunaan: menghasilkan berkas checksums.txt (format: "<sha256>  <nama>")
# berisi hash artefak yang diverifikasi oleh installer (zidstoretunnel.sh)
# pada saat self-update maupun unduhan eksternal.
#
# Cara pakai (dari root repo):
#   ./scripts/gen_checksums.sh                 # menulis ./checksums.txt
#   ./scripts/gen_checksums.sh /path/lain.txt  # path output kustom
#
# Instruksi unggah: salin berkas hasil ke /www/ZidStoreAPI/resources/checksums.txt
# di server API (ZidStoreAPI) agar dapat diunduh installer via
# ${ZIDSTORE_API_URL}/resources/checksums.txt.
#
# Membutuhkan jaringan untuk mengunduh artefak eksternal (setup_22.x,
# xray-install.sh, acme-install.sh, xray.linux.64bit, udp-custom-linux-amd64,
# badvpn, openvpn.zip, src.zip, bot.zip). Artefak
# zidstoretunnel dihitung dari berkas encoded lokal di root repo.

set -euo pipefail

OUTPUT="${1:-checksums.txt}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

RESULT="$TMPDIR/checksums.txt"
: > "$RESULT"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# zidstoretunnel: artefak encoded lokal di root repo
HASH=$(sha256sum "$REPO_ROOT/zidstoretunnel" | awk '{print $1}')
printf '%s  zidstoretunnel\n' "$HASH" >> "$RESULT"

# setup_22.x (NodeSource)
curl -fsSL -o "$TMPDIR/setup_22.x" https://deb.nodesource.com/setup_22.x
HASH=$(sha256sum "$TMPDIR/setup_22.x" | awk '{print $1}')
printf '%s  setup_22.x\n' "$HASH" >> "$RESULT"

# xray-install.sh (XTLS official installer)
curl -fsSL -o "$TMPDIR/xray-install.sh" https://github.com/XTLS/Xray-install/raw/main/install-release.sh
HASH=$(sha256sum "$TMPDIR/xray-install.sh" | awk '{print $1}')
printf '%s  xray-install.sh\n' "$HASH" >> "$RESULT"

# acme-install.sh
curl -fsSL -o "$TMPDIR/acme-install.sh" https://get.acme.sh
HASH=$(sha256sum "$TMPDIR/acme-install.sh" | awk '{print $1}')
printf '%s  acme-install.sh\n' "$HASH" >> "$RESULT"

# xray.linux.64bit (fallback binary)
curl -fsSL -o "$TMPDIR/xray.linux.64bit" https://raw.githubusercontent.com/zidnyzd/linux/main/xray/xray.linux.64bit
HASH=$(sha256sum "$TMPDIR/xray.linux.64bit" | awk '{print $1}')
printf '%s  xray.linux.64bit\n' "$HASH" >> "$RESULT"

# Biner fodder dari server API ZidStore (path yang sama dengan installer)
FODDER_BASE="https://zds.web.id/resources/fodder"
for fodder in udp-custom-linux-amd64 badvpn openvpn.zip sqlite3-prebuilt.tar.gz; do
    curl -fsSL -o "$TMPDIR/$fodder" "$FODDER_BASE/$fodder"
    HASH=$(sha256sum "$TMPDIR/$fodder" | awk '{print $1}')
    printf '%s  %s\n' "$HASH" "$fodder" >> "$RESULT"
done

# src.zip (isi src-bin) dan bot.zip
curl -fsSL -o "$TMPDIR/src.zip" https://zds.web.id/resources/src-bin/src.zip
HASH=$(sha256sum "$TMPDIR/src.zip" | awk '{print $1}')
printf '%s  src.zip\n' "$HASH" >> "$RESULT"

curl -fsSL -o "$TMPDIR/bot.zip" https://zds.web.id/resources/bot/bot.zip
HASH=$(sha256sum "$TMPDIR/bot.zip" | awk '{print $1}')
printf '%s  bot.zip\n' "$HASH" >> "$RESULT"

cp "$RESULT" "$OUTPUT"
echo "Wrote $OUTPUT"