#!/bin/sh

NGROK_BASE="https://2658-68-183-229-11.ngrok-free.app/firmware"

download_firmware() {
    FILE="$1"
    OUT="$2"
    MAX_RETRIES=3
    COUNT=1

    while [ $COUNT -le $MAX_RETRIES ]; do
        echo "📥 Downloading $FILE (attempt $COUNT/$MAX_RETRIES)..."
        curl -fSL "$NGROK_BASE/$FILE" -o "$OUT" && {
            echo "✅ Download berhasil! File disimpan sebagai: $OUT"
            return 0
        }
        echo "⚠️  Gagal download $FILE, mencoba lagi..."
        COUNT=$((COUNT + 1))
        sleep 2
    done

    echo "❌ Gagal mengunduh $FILE setelah $MAX_RETRIES kali percobaan." >&2
    return 1
}

echo "============================"
echo "   OTA Firmware Downloader  "
echo "============================"
echo "1) LedeProject.bin"
echo "2) PakawrtNssbin"
echo "0) Keluar"
echo "----------------------------"
printf "Pilih file firmware [1-2]: "
read PILIHAN

case "$PILIHAN" in
    1)
        download_firmware "LedeProject.bin" "LedeProject.bin"
        ;;
    2)
        download_firmware "PakawrtNssbin" "PakawrtNssbin"
        ;;
    0)
        echo "Keluar."
        ;;
    *)
        echo "Pilihan tidak valid."
        ;;
esac
