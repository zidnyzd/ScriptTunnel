# 05 Build dan Obfuscasi

## Pipeline Build pada build.sh

`build.sh` mengubah skrip sumber `zidstoretunnel.sh` menjadi berkas self-extracting bernama `zidstoretunnel` yang dapat diunduh dan dijalankan langsung oleh pengguna akhir. Berkas output tidak bisa dibaca manusia, tetapi saat dieksekusi akan mendekode sumbernya dan menjalankannya.

### Langkah 1: Baca zidstoretunnel.sh

Berkas sumber dibaca dari direktori kerja:

```
INPUT_FILE="zidstoretunnel.sh"
OUTPUT_FILE="zidstoretunnel"
```

Rujukan: `build.sh:20-21`. Skrip memeriksa keberadaan berkas sumber terlebih dahulu:

```
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: $INPUT_FILE not found${NC}"
    exit 1
fi
```

Rujukan: `build.sh:44-47`. Ukuran berkas sumber diukur:

```
SOURCE_SIZE=$(wc -c < "$INPUT_FILE")
```

Rujukan: `build.sh:53`.

Versi dibaca dari `VERSION`:

```
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
```

Rujukan: `build.sh:50`.

### Langkah 2: Kompresi gzip dan Encoding Base64

Sumber dikompresi dengan `gzip -c` lalu di-encode ke base64 tanpa wrap:

```
COMPRESSED=$(gzip -c "$INPUT_FILE" | base64 -w 0)
COMPRESSED_SIZE=${#COMPRESSED}
```

Rujukan: `build.sh:57-59`. Opsi `-w 0` mencegah base64 memasukkan baris baru, sehingga output adalah satu baris string panjang yang sulit diolah secara mentah dengan grep sederhana.

Ukuran kompresi dihitung:

```
COMPRESSED_SIZE=${#COMPRESSED}
echo -e "  Compressed size: ${COMPRESSED_SIZE} characters"
```

Rujukan: `build.sh:58-59`.

### Langkah 3: Pembagian String Base64 menjadi Chunk 3072 Karakter

String base64 yang dikompresi dibagi menjadi potongan-potongan (chunk) sebesar 3072 karakter:

```
CHUNK_SIZE=3072
NUM_CHUNKS=$(( (COMPRESSED_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))
```

Rujukan: `build.sh:75-76`. Pembagian ini memastikan masing-masing variabel Bash tidak terlalu panjang untuk memuat satu chunk, sehingga skrip tetap kompatibel dengan batas variabel Bash.

Nama variabel acak di-generate dari UUID:

```
UUID_BIN="cat /proc/sys/kernel/random/uuid"
command -v uuidgen &>/dev/null && UUID_BIN="uuidgen"

RAND_D1=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_D2=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_D3=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_D4=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_F1=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
```

Rujukan: `build.sh:64-72`. Keempat variabel (`RAND_D1` sampai `RAND_D4`) dan satu variabel tambahan (`RAND_F1`) digunakan untuk nama variabel dan nama fungsi loader, sehingga setiap build menghasilkan nama yang berbeda.

Blok deklarasi variabel dibangun untuk setiap chunk:

```
for ((i=0; i<NUM_CHUNKS; i++)); do
    START=$((i * CHUNK_SIZE))
    CHUNK="${COMPRESSED:$START:$CHUNK_SIZE}"
    HEX_I=$(printf '%x' "$i")
    VAR_DECLS+="__${RAND_D1}_${HEX_I}=\"${CHUNK}\"
"
done
```

Rujukan: `build.sh:79-87`. Indeks chunk ditulis dalam heksadesimal, misalnya `__<uuid>_0`, `__<uuid>_1`, dst.

Blok penggabungan array dibangun:

```
for ((i=0; i<NUM_CHUNKS; i++)); do
    HEX_I=$(printf '%x' "$i")
    ASSEMBLY_BLOCK+="\${__${RAND_D1}_${HEX_I}}"
done
```

Rujukan: `build.sh:90-94`.

Fungsi loader dibangun di dalam output:

```
__${RAND_F1}() {
${VAR_DECLS}
    printf '%s' "${ASSEMBLY_BLOCK}" | base64 -d | gzip -d
}

__${RAND_D2}=\$(__${RAND_F1})

if [ -z "\${__${RAND_D2}}" ]; then
    echo "[!] Error: Failed to decode installer payload" >&2
    exit 1
fi

bash -c "\${__${RAND_D2}}" -- "\$@"
```

Rujukan: `build.sh:104-120`. Langkah terakhir mengeksekusi string yang sudah didekode dengan `bash -c` dan meneruskan semua argumen (`$@`).

### Langkah 4: Akhirisasi Output

Output ditulis ke `zidstoretunnel` dengan izin eksekusi:

```
chmod +x "$OUTPUT_FILE"
OUTPUT_SIZE=$(wc -c < "$OUTPUT_FILE")
```

Rujukan: `build.sh:122`, `build.sh:126`.

## Tata Cara Membuild Release Baru

1. Edit `zidstoretunnel.sh` sesuai kebutuhan.
2. Perbarui `ZIDSTORE_VERSION` di `zidstoretunnel.sh:8`.
3. Perbarui `VERSION` di berkas `VERSION` (saat ini berisi `1.0.3`).
4. Jalankan `./build.sh`. Opsional, berikan `--update-url` untuk mengonfigurasi URL pembaruan otomatis:

```
chmod +x build.sh
./build.sh --update-url https://raw.githubusercontent.com/zidnyzd/ScriptTunnel/main/zidstoretunnel
```

Rujukan: `build.sh:143-145`, `zidstoretunnel.sh:89-166`.
5. Di dalam `build.sh`, output versi dicetak sebagai `v${VERSION}` (`build.sh:134`).
6. Commit dan push hanya berkas `zidstoretunnel` (bukan `zidstoretunnel.sh`) bersama `VERSION` dan `CHANGELOG.md`:

```
git add zidstoretunnel VERSION CHANGELOG.md
git commit -m "v1.0.1 - description"
git push
```

Rujukan: `README.md:164-167`.
7. Pengguna akhir menginstal dengan:

```
curl -sL https://raw.githubusercontent.com/zidnyzd/ScriptTunnel/main/zidstoretunnel | sudo bash
```

Rujukan: `README.md:33`, `build.sh:141`.

## Analisis Keamanan dan Batasan Deobfuscation

### Bagian yang Dilindungi

- Isi logika instalasi tidak ada di berkas `zidstoretunnel` yang didistribusikan, melainkan dalam variabel acak dan fungsi loader.
- Pemotongan base64 menjadi variabel terpisah dengan nama acak mencegah ekstraksi pola sederhana melalui regex satu baris.
- Nama variabel dan fungsi di-randomisasi per-build, sehingga dua build dari sumber yang sama menghasilkan output yang berbeda secara teks.

### Batasan

1. Loader masih adalah skrip Bash yang dieksekusi. Analisis statis dapat membaca fungsi `__<RAND_F1>`, melihat blok deklarasi variabel, dan menggabungkan semua chunk secara berurutan.
2. Dekode payload dapat dijalankan secara manual:

```
printf '%s' "${chunk1}${chunk2}..." | base64 -d | gzip -d
```

3. `build.sh` tidak menggunakan enkripsi, hanya kompresi dan encoding. Anggota tim yang memiliki akses ke `zidstoretunnel` dapat mengembalikannya ke bentuk sumber dengan menggabungkan chunk dan menjalankan `base64 -d | gzip -d`.
4. Tidak ada tanda tangan digital atau verifikasi integritas pada berkas `zidstoretunnel`. Jika URL berkas diubah, pengguna akan menjalankan kode dari sumber yang tidak terverifikasi.
5. Auto-update (`--update`) di v1.0.3 mengunduh pembaruan ke berkas sementara dan manifest `checksums.txt` dari `${ZIDSTORE_API_URL}/resources/checksums.txt`, memverifikasi SHA256 terhadap manifest, baru mengeksekusi dengan `--key` diteruskan. Gagal verifikasi menghentikan pembaruan (fail closed). Perilaku baru mengikuti baris `zidstoretunnel.sh:89-166`.

Rujukan: `zidstoretunnel.sh:89-166`.

### Rekomendasi

- Jangan meng-upload `zidstoretunnel.sh` ke repositori publik.
- Jangan membagikan `zidstoretunnel` tanpa memverifikasi keasliannya melalui hash atau sumber tepercaya.
- Pertahankan pemeriksaan integritas (sha256) pada `--update` dan unduhan eksternal terhadap manifest `checksums.txt` di setiap rilis.

## Rujukan Berkas:Baris

| Berkas:Baris | Fungsi |
|---|---|
| `build.sh:1-3` | Header dan deskripsi build |
| `build.sh:20-21` | Definisi INPUT_FILE dan OUTPUT_FILE |
| `build.sh:24-36` | Parsing argumen --update-url |
| `build.sh:44-47` | Pengecekan keberadaan sumber |
| `build.sh:50` | Pembacaan VERSION |
| `build.sh:53` | Ukuran sumber |
| `build.sh:57-59` | Kompresi gzip dan base64 -w 0 |
| `build.sh:64-72` | Generate nama variabel acak |
| `build.sh:75-76` | Chunk size 3072 dan hitung jumlah chunk |
| `build.sh:79-87` | Deklarasi variabel chunk |
| `build.sh:90-94` | Penggabungan chunk |
| `build.sh:104-120` | Loader self-extracting |
| `build.sh:122` | Izin eksekusi output |
| `build.sh:126` | Ukuran output |
| `build.sh:134` | Cetak versi output |
| `build.sh:141` | Perintah instal pengguna |
| `build.sh:143-145` | URL auto-update |
| `zidstoretunnel.sh:8` | Variabel ZIDSTORE_VERSION |
| `zidstoretunnel.sh:89-166` | Fungsi --update |
| `zidstoretunnel.sh:114-116` | Eksekusi skrip pembaruan terverifikasi dengan --key |
| `README.md:64-68` | Default variabel konfigurasi build |
| `README.md:164-167` | Panduan commit build |
