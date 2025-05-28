#!/bin/sh

echo "============================="
echo "   OTA Firmware Downloader"
echo "============================="
echo ""
echo "Pilih firmware yang ingin diunduh:"
echo "1) PakaWRT NSS Build"
echo "2) Lede Project Build"
echo ""

read -p "Masukkan pilihan (1/2): " pilihan

case "$pilihan" in
  1)
    URL="https://f941-68-183-229-11.ngrok-free.app/firmware/PakawrtNss.bin"
    ;;
  2)
    URL="https://f941-68-183-229-11.ngrok-free.app/firmware/LedeProject.bin"
    ;;
  *)
    echo "[ERROR] Pilihan tidak valid."
    exit 1
    ;;
esac

DEST="/tmp/firmware.bin"

echo ""
echo "[INFO] Mengunduh firmware dari:"
echo "$URL"
echo ""

curl -L "$URL" -o "$DEST"

if [ $? -ne 0 ]; then
  echo "[ERROR] Gagal mengunduh firmware."
  exit 1
fi

SIZE=$(stat -c%s "$DEST")
if [ "$SIZE" -lt 3000000 ]; then
  echo "[ERROR] Ukuran file terlalu kecil ($SIZE bytes), kemungkinan gagal download."
  exit 1
fi

echo ""
echo "[SUKSES] Firmware berhasil diunduh ke: $DEST"
echo "Silakan jalankan 'sysupgrade /tmp/firmware.bin' jika ingin melakukan flashing."
