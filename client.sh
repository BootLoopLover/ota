#!/bin/sh

OTA_SERVER="https://ota.pakawrt.me"  # ganti sesuai URL server OTA kamu

echo "=== PakaWRT OTA Client ==="
echo -n "Masukkan username Telegram kamu (tanpa @): "
read USERNAME

if [ -z "$USERNAME" ]; then
  echo "Username tidak boleh kosong!"
  exit 1
fi

# Cek token di server (misal endpoint: /check_token?user=USERNAME)
CHECK_URL="$OTA_SERVER/check_token?user=$USERNAME"

echo "Memeriksa status token untuk user '$USERNAME'..."

STATUS=$(wget -qO- "$CHECK_URL" 2>/dev/null)
# Contoh response server:
# {"status":"pending"}  atau {"status":"approved"} atau {"status":"not_found"}

case "$STATUS" in
  *"approved"*)
    echo "Token sudah di-approve! Berikut daftar firmware tersedia:"
    # Ambil daftar firmware dari server (misal /firmware_list)
    wget -qO- "$OTA_SERVER/firmware_list" | sed 's/^/ - /'
    ;;
  *"pending"*)
    echo "Token kamu masih dalam proses approval. Silakan hubungi admin:"
    echo "Telegram: https://t.me/PakaloloWaras0"
    ;;
  *"not_found"*)
    echo "Token tidak ditemukan. Silakan registrasi terlebih dahulu melalui admin."
    echo "Telegram: https://t.me/PakaloloWaras0"
    ;;
  *)
    echo "Terjadi kesalahan saat memeriksa status token."
    ;;
esac
