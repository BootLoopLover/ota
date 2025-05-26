#!/bin/bash

# === Konfigurasi awal ===
TUNNEL_NAME="pakalolo-ota-tunnel-v2"
LOCAL_PORT="5000"
CONFIG_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# === Pastikan cloudflared sudah login ===
if [ ! -f "$CONFIG_DIR/cert.pem" ]; then
    echo "Belum login Cloudflare. Membuka login..."
    cloudflared tunnel login || exit 1
else
    echo "Sudah login Cloudflare ✔"
fi

# === Ambil credentials file ===
echo "Mengambil credentials untuk tunnel: $TUNNEL_NAME..."
cloudflared tunnel token "$TUNNEL_NAME" || exit 1

# === Deteksi file credentials JSON ===
CRED_FILE=$(find "$CONFIG_DIR" -name "*.json" | grep "$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')" | head -n1)

if [ ! -f "$CRED_FILE" ]; then
    echo "❌ Gagal menemukan credentials file untuk tunnel $TUNNEL_NAME"
    exit 1
fi

echo "✔ Credentials ditemukan: $CRED_FILE"

# === Tulis config.yaml ===
cat <<EOF > "$CONFIG_FILE"
tunnel: $TUNNEL_NAME
credentials-file: $CRED_FILE
ingress:
  - service: http://localhost:$LOCAL_PORT
  - service: http_status:404
EOF

echo "✔ File config.yaml berhasil ditulis di: $CONFIG_FILE"

# === Jalankan tunnel ===
echo "🚀 Menjalankan tunnel Cloudflare untuk OTA..."
cloudflared tunnel run "$TUNNEL_NAME"
