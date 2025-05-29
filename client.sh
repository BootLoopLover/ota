#!/bin/sh

SERVER="https://ota.pakawrt.me"

echo "=== PakaWRT OTA Client ==="
echo -n "Masukkan username Telegram kamu: "
read USER

STATUS=$(curl -s "$SERVER/status/$USER" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ "$STATUS" != "approved" ]; then
    echo "❌ Username *$USER* belum di-approve."
    echo "Silakan hubungi admin di Telegram: @PakaloloWaras0"
    exit 1
fi

echo "✅ Username $USER sudah di-approve."
echo "Mengambil daftar firmware..."

LIST=$(curl -s "$SERVER/firmware_list_raw")

if [ -z "$LIST" ]; then
    echo "⚠️  Tidak ada firmware tersedia."
    exit 1
fi

echo "$LIST" | nl
echo -n "Pilih nomor firmware yang ingin diunduh: "
read NUM

FILE=$(echo "$LIST" | sed -n "${NUM}p")

if [ -z "$FILE" ]; then
    echo "❌ Nomor tidak valid!"
    exit 1
fi

echo "📥 Mengunduh firmware: $FILE ..."
curl -O "$SERVER/firmware/$FILE"

# Hapus skrip ini sendiri
SCRIPT_PATH=$(realpath "$0")
[ -f "$SCRIPT_PATH" ] && echo "🧹 Menghapus skrip..." && rm -f "$SCRIPT_PATH"
