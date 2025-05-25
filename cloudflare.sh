#!/bin/bash
set -e

echo "=== [1/6] Install cloudflared ==="
if ! command -v cloudflared >/dev/null 2>&1; then
    curl -s https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install/linux/ | bash
else
    echo "✅ cloudflared already installed."
fi

echo "=== [2/6] Login ke Cloudflare ==="
mkdir -p ~/.cloudflared

cloudflared login || {
    echo "❌ Login gagal. Pastikan browser terbuka dan kamu pilih domain yang benar."
    exit 1
}

json_file=$(find ~/.cloudflared -type f -name '*.json' | head -n 1)
if [[ ! -f "$json_file" ]]; then
    echo "❌ Tidak ditemukan file credentials (.json). Login mungkin gagal."
    exit 1
fi

echo "✅ Login sukses. File kredensial ditemukan: $json_file"

echo "=== [3/6] Membuat tunnel ==="
TUNNEL_NAME="desktop-tunnel"
cloudflared tunnel delete $TUNNEL_NAME 2>/dev/null || true
cloudflared tunnel create $TUNNEL_NAME

tunnel_id=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
echo "✅ Tunnel dibuat: ID $tunnel_id"

echo "=== [4/6] Membuat config.yml ==="
cat > ~/.cloudflared/config.yml <<EOF
tunnel: $tunnel_id
credentials-file: $json_file

ingress:
  - hostname: ssh.pakalolo.me
    service: ssh://localhost:22
  - service: http_status:404
EOF

echo "✅ Konfigurasi dibuat: ~/.cloudflared/config.yml"

echo "=== [5/6] Routing domain ke tunnel ==="
cloudflared tunnel route dns $TUNNEL_NAME ssh.pakalolo.me

echo "✅ Domain ssh.pakalolo.me dihubungkan ke tunnel"

echo "=== [6/6] Menjalankan tunnel ==="
cloudflared tunnel run $TUNNEL_NAME
