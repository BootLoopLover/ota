#!/bin/sh

SERVER="https://ota.pakawrt.me"

echo -n "Username Telegram: "
read USER

STATUS=$(curl -s "$SERVER/status/$USER" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ "$STATUS" != "approved" ]; then
    echo "❌ Belum di-approve. Hubungi admin @PakaloloWaras0"
    exit 1
fi

echo "✅ Approved. Mendapatkan daftar firmware..."
curl -s "$SERVER/firmware_list/$USER" | jq -r '.[]' | nl

echo -n "Pilih nomor firmware: "
read NUM

FILE=$(curl -s "$SERVER/firmware_list/$USER" | jq -r ".[$((NUM-1))]")

curl -O "$SERVER/firmware/$FILE"
