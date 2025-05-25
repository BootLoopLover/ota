#!/bin/bash

echo "======================================"
echo "     🔐 Cloudflare Tunnel Setup       "
echo "======================================"

read -p "Masukkan subdomain yang ingin digunakan (contoh: mypc.pakalolo.me): " SUBDOMAIN
read -p "Masukkan port lokal yang ingin di-expose (contoh: 80 untuk web, 22 untuk SSH): " PORT
read -p "Masukkan nama tunnel (bebas, contoh: desktop-tunnel): " TUNNEL_NAME

# 1. Install cloudflared
echo "[1/6] Installing cloudflared..."
sudo apt update
sudo apt install -y cloudflared || {
    echo "Gagal install cloudflared."; exit 1;
}

# 2. Login Cloudflare
echo "[2/6] Login ke Cloudflare..."
cloudflared login || {
    echo "Login Cloudflare gagal."; exit 1;
}

# 3. Create tunnel
echo "[3/6] Membuat tunnel..."
cloudflared tunnel create "$TUNNEL_NAME" || {
    echo "Gagal membuat tunnel."; exit 1;
}

# 4. Buat file config.yml
echo "[4/6] Membuat config file..."
mkdir -p ~/.cloudflared
CONFIG_PATH="$HOME/.cloudflared/config.yml"
CRED_PATH="$HOME/.cloudflared/${TUNNEL_NAME}.json"

cat > "$CONFIG_PATH" <<EOF
tunnel: $TUNNEL_NAME
credentials-file: $CRED_PATH

ingress:
  - hostname: $SUBDOMAIN
    service: http://localhost:$PORT
  - service: http_status:404
EOF

# 5. Assign subdomain
echo "[5/6] Menyambungkan $SUBDOMAIN ke tunnel..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$SUBDOMAIN"

# 6. Install sebagai systemd service
echo "[6/6] Mengaktifkan Cloudflare Tunnel sebagai service..."
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl restart cloudflared

echo
echo "✅ Selesai! Subdomain aktif: https://$SUBDOMAIN"
echo "🚀 Akses port lokal $PORT kamu sekarang terbuka ke publik melalui Cloudflare."
