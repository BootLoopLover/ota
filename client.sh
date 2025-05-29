#!/bin/sh
# client.sh - Simple OTA update client for PakaWRT

BASE_URL="https://ota.pakawrt.me"

echo "=== PakaWRT OTA Client ==="
echo "Masukkan username Telegram kamu:"
read -r USERNAME

if [ -z "$USERNAME" ]; then
  echo "Username tidak boleh kosong!"
  exit 1
fi

echo "Memeriksa token username: $USERNAME ..."

# Request token info dari server (contoh endpoint)
RESPONSE=$(wget -qO- "$BASE_URL/api/check_token?user=$USERNAME")

if echo "$RESPONSE" | grep -q "approved"; then
  echo "Token sudah approved. Daftar firmware tersedia:"
  wget -qO- "$BASE_URL/api/firmware_list" | tee /tmp/firmware_list.txt
  echo "Silakan pilih firmware yang ingin diunduh."
else
  echo "Token belum disetujui. Silakan hubungi admin di:"
  echo "https://t.me/PakaloloWaras0"
fi
