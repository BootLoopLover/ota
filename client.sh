#!/bin/sh

# Konfigurasi
SERVER="https://ota.pakalolo.me"
USERNAME="mydevice001"       # Ganti dengan nama unik device kamu
FIRMWARE_NAME="firmware.bin" # Ganti jika nama file firmware berbeda

# 1. Register ke server
echo "[INFO] Mendaftarkan perangkat ke server OTA..."
curl -s -X POST -H "Content-Type: application/json" \
     -d "{\"username\":\"$USERNAME\"}" \
     "$SERVER/register" > /dev/null

# 2. Cek status approval
echo "[INFO] Menunggu approval dari admin..."
while true; do
  STATUS=$(curl -s "$SERVER/status/$USERNAME" | grep -o 'approved')
  if [ "$STATUS" = "approved" ]; then
    echo "[INFO] Perangkat telah di-approve."
    break
  fi
  sleep 10
done

# 3. Unduh firmware
FIRMWARE_URL="$SERVER/firmware/$USERNAME/$FIRMWARE_NAME"
DEST_PATH="/tmp/$FIRMWARE_NAME"
echo "[INFO] Mengunduh firmware dari: $FIRMWARE_URL"
curl -f -o "$DEST_PATH" "$FIRMWARE_URL"

# 4. Verifikasi ukuran file
if [ ! -s "$DEST_PATH" ]; then
  echo "[ERROR] Gagal mengunduh firmware atau file kosong."
  exit 1
fi

# 5. Flash firmware
echo "[INFO] Memulai proses flashing firmware..."
sysupgrade "$DEST_PATH"
