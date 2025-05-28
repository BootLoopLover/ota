#!/bin/sh

SERVER_URL="https://2658-68-183-229-11.ngrok-free.app/firmware"  # ganti dengan URL aktif

show_menu() {
  echo "============================"
  echo "1) LedeProject.bin"
  echo "2) PakawrtNss.bin"
  echo "0) Keluar"
  echo "----------------------------"
  echo -n "Pilih file firmware [1-2]: "
}

download_firmware() {
  FILE_NAME="$1"
  for i in 1 2 3; do
    echo "📥 Downloading $FILE_NAME (attempt $i/3)..."
    curl -fLo "$FILE_NAME" "$SERVER_URL/$FILE_NAME" && {
      echo "✅ Berhasil download $FILE_NAME"
      return 0
    }
    echo "⚠️  Gagal download $FILE_NAME, mencoba lagi..."
    sleep 2
  done
  echo "❌ Gagal mengunduh $FILE_NAME setelah 3 kali percobaan."
}

while true; do
  show_menu
  read pilihan
  case $pilihan in
    1) download_firmware "LedeProject.bin"; break ;;
    2) download_firmware "PakawrtNss.bin"; break ;;
    0) echo "Keluar."; break ;;
    *) echo "❌ Pilihan tidak valid." ;;
  esac
done
