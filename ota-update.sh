#!/bin/sh

SERVER="https://ota.pakawrt.me"

echo "=== PakaWRT OTA Client ==="
echo -n "Masukkan username Telegram kamu: "
read USER

STATUS=$(curl -s "$SERVER/status/$USER" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ "$STATUS" != "approved" ]; then
    echo "❌ Username belum di-approve. Hubungi admin."
    exit 1
fi

echo "✅ Username sudah di-approve."

# Ambil daftar firmware dan simpan ke array
FIRMWARE_LIST=$(curl -s "$SERVER/firmware_list_raw")
if [ -z "$FIRMWARE_LIST" ]; then
    echo "⚠️ Daftar firmware kosong atau gagal mengambil data."
    exit 1
fi

# Tampilkan daftar dengan nomor
echo "Daftar firmware yang tersedia:"
i=1
echo "$FIRMWARE_LIST" | while IFS= read -r line; do
    echo "  $i) $line"
    i=$((i+1))
done

# Input pilihan user
echo -n "Pilih nomor firmware untuk download: "
read NUM

# Validasi input angka dan apakah ada file sesuai nomor
TOTAL=$(echo "$FIRMWARE_LIST" | wc -l)
if ! echo "$NUM" | grep -qE '^[0-9]+$' || [ "$NUM" -lt 1 ] || [ "$NUM" -gt "$TOTAL" ]; then
    echo "❌ Pilihan tidak valid."
    exit 1
fi

# Ambil nama file sesuai nomor pilihan
FILE=$(echo "$FIRMWARE_LIST" | sed -n "${NUM}p")

echo "Mengunduh firmware: $FILE"
curl -O "$SERVER/firmware/$FILE"

if [ $? -eq 0 ]; then
    echo "✅ Firmware berhasil diunduh: $FILE"
else
    echo "❌ Gagal mengunduh firmware."
fi
