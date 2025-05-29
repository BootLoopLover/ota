#!/bin/sh

SERVER="https://ota.pakawrt.me"

echo "=== PakaWRT OTA Client ==="
echo -n "Masukkan username Telegram kamu: "
read USERNAME

if [ -z "$USERNAME" ]; then
    echo "Username tidak boleh kosong."
    exit 1
fi

echo "Cek status approval untuk user $USERNAME..."
STATUS=$(curl -s "$SERVER/status/$USERNAME" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ "$STATUS" != "approved" ]; then
    echo "User belum disetujui admin. Silakan hubungi admin @PakaloloWaras0 di Telegram."
    exit 1
fi

echo "User sudah disetujui. Mengambil daftar firmware..."
curl -s "$SERVER/firmware_list/$USERNAME" | jq -r '.[]' | nl

echo -n "Masukkan nomor firmware yang ingin diunduh: "
read NO

if ! echo "$NO" | grep -q '^[0-9]\+$'; then
    echo "Input salah."
    exit 1
fi

FIRMWARE=$(curl -s "$SERVER/firmware_list/$USERNAME" | jq -r ".[$((NO-1))]")

if [ -z "$FIRMWARE" ] || [ "$FIRMWARE" = "null" ]; then
    echo "Pilihan firmware tidak valid."
    exit 1
fi

echo "Mengunduh firmware $FIRMWARE ..."
curl -O "$SERVER/firmware/$FIRMWARE"

echo "Selesai."
