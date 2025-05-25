#!/bin/bash

echo "=== [1/6] Install cloudflared ==="
if ! command -v cloudflared &>/dev/null; then
    curl -s https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install/linux/ | sudo bash
else
    echo "✅ cloudflared already installed."
fi

echo "=== [2/6] Login ke Cloudflare ==="
cloudflared login
if [ $? -ne 0 ]; then
    echo "❌ Login gagal. Keluar..."
    exit 1
fi

echo "=== [3/6] Buat Tunnel Baru ==="
read -p "Masukkan nama tunnel (misal: desktop-tunnel): " TUNNEL_NAME
cloudflared tunnel create "$TUNNEL_NAME"
if [ $? -ne 0 ]; then
    echo "❌ Gagal membuat tunnel."
    exit 1
fi

TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
CRED_FILE="$HOME/.cloudflared/${TUNNEL_ID}.json"

echo "=== [4/6] Buat config.yml ==="
mkdir -p ~/.cloudflared
cat <<EOF > ~/.cloudflared/config.yml
tunnel: $TUNNEL_ID
credentials-file: $CRED_FILE

ingress:
  - hostname: ssh.pakalolo.me
    service: ssh://localhost:22
  - service: http_status:404
EOF

echo "✅ Konfigurasi tersimpan di ~/.cloudflared/config.yml"

echo "=== [5/6] Daftarkan DNS ssh.pakalolo.me ==="
cloudflared tunnel route dns "$TUNNEL_NAME" ssh.pakalolo.me

echo "=== [6/6] Setup sebagai systemd service ==="
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

echo ""
echo "✅ Tunnel SSH aktif di: ssh.pakalolo.me"
echo "🔐 Coba akses: ssh [username]@ssh.pakalolo.me"
