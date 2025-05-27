#!/bin/sh

OTA_URL="https://c208-68-183-229-11.ngrok-free.app/firmware"

echo ""
echo "📡 Mengambil daftar firmware dari OTA Server..."
FILES="
LedeProject.bin
PakawrtNss.bin
"

i=1
for f in $FILES; do
    echo "$i) $f"
    eval "f$i='$f'"
    i=$((i+1))
done

echo ""
read -p "Pilih firmware [1-$(($i-1))]: " CHOICE
eval "FIRMWARE=\$f$CHOICE"

if [ -z "$FIRMWARE" ]; then
    echo "❌ Pilihan tidak valid."
    exit 1
fi

echo ""
echo "📥 Mengunduh: $FIRMWARE"
wget "$OTA_URL/$FIRMWARE" -O "/tmp/$FIRMWARE"

if [ $? -ne 0 ]; then
    echo "❌ Gagal mengunduh firmware."
    exit 1
fi

echo ""
echo "⚠️  Firmware berhasil diunduh ke /tmp/$FIRMWARE"
read -p "Lanjutkan flashing dengan sysupgrade? [y/N]: " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "❌ Dibatalkan oleh pengguna."
    exit 0
fi

echo ""
echo "⚡ Memulai proses flashing..."
sysupgrade "/tmp/$FIRMWARE"
