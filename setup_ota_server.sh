#!/bin/bash

PORT=5001
TUNNEL_NAME="pakalolo-ota-tunnel"
CLOUDFLARED_DIR="$HOME/home/paka/.cloudflared"
CONFIG_FILE="$CLOUDFLARED_DIR/home/paka/.cloudflared/config.yml"
CREDENTIAL_FILE="$CLOUDFLARED_DIR/$TUNNEL_NAME.json"

echo "✅ Menjalankan OTA Server di port $PORT..."

# Jalankan OTA server di background
nohup python3 ota_server.py $PORT >/dev/null 2>&1 &

# Cek dan buat config.yml jika tidak ada
if [ ! -f "$CONFIG_FILE" ]; then
    echo "🔄 Membuat config.yml di $CONFIG_FILE..."
    mkdir -p "$CLOUDFLARED_DIR"
    cat <<EOF > "$CONFIG_FILE"
tunnel: $TUNNEL_NAME
credentials-file: $CREDENTIAL_FILE
ingress:
  - hostname: ota.pakalolo.me
    service: http://localhost:$PORT
  - service: http_status:404
EOF
fi

# Periksa credential tunnel
if [ ! -f "$CREDENTIAL_FILE" ]; then
    echo "❌ Gagal menemukan credential tunnel: $CREDENTIAL_FILE"
    echo "📌 Jalankan perintah berikut untuk login dan buat ulang tunnel:"
    echo ""
    echo "   cloudflared tunnel login"
    echo "   cloudflared tunnel create $TUNNEL_NAME"
    echo ""
    exit 1
fi

# Jalankan Cloudflare Tunnel
echo "🚀 Menjalankan Cloudflare Tunnel ($TUNNEL_NAME)..."
cloudflared tunnel run "$TUNNEL_NAME"
