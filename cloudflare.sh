#!/bin/bash
set -e

# Step 1: Input Info
read -p "ENTER MAIN DOMAIN (e.g., pakalolo.me): " DOMAIN
read -p "ENTER SUBDOMAIN (e.g., ota): " SUBDOMAIN
read -p "ENTER TUNNEL NAME (e.g., otatunnel): " TUNNEL_NAME
read -p "ENTER LOCAL SERVICE PORT (e.g., 5000): " SERVICE_PORT

FULL_DOMAIN="$SUBDOMAIN.$DOMAIN"

# Step 2: Install cloudflared
echo "[1/7] INSTALLING CLOUDFLARED..."

ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    wget -O cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm -f cloudflared.deb
elif [[ "$ARCH" == "aarch64" ]]; then
    wget -O cloudflared.tgz https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.tgz
    tar -xvzf cloudflared.tgz
    sudo mv cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared
    rm -f cloudflared.tgz
else
    echo "Unsupported architecture. Please install cloudflared manually."
    exit 1
fi

if ! command -v cloudflared >/dev/null 2>&1; then
    echo "CLOUDFLARED INSTALLATION FAILED."
    exit 1
fi

# Step 3: Login Cloudflare
echo "[2/7] LOGGING INTO CLOUDFLARE"
sudo rm -f /etc/cloudflared/config.yml
cloudflared tunnel login

# Step 4: Create tunnel
echo "[3/7] CREATING TUNNEL: $TUNNEL_NAME"
cloudflared tunnel delete "$TUNNEL_NAME" 2>/dev/null || true
cloudflared tunnel create "$TUNNEL_NAME"

# Step 5: Create config.yml
echo "[4/7] CREATING CONFIGURATION FILE"
CRED_FILE=$(find ~/.cloudflared -name "$TUNNEL_NAME*.json" | head -n 1)
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_NAME
credentials-file: $CRED_FILE
ingress:
  - hostname: $FULL_DOMAIN
    service: http://localhost:$SERVICE_PORT
  - service: http_status:404
EOF

# Step 6: Route DNS
echo "[5/7] ROUTING DNS $FULL_DOMAIN TO TUNNEL"
cloudflared tunnel route dns "$TUNNEL_NAME" "$FULL_DOMAIN"

# Step 7: Systemd Service
echo "[6/7] CREATING SYSTEMD SERVICE"
sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=Cloudflared Tunnel
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
Restart=always
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

# Final Step: Status
echo "[7/7] TUNNEL STATUS:"
sudo systemctl status cloudflared --no-pager

echo ""
echo "✅ TUNNEL IS ACTIVE!"
echo "▶️ Access it via: https://$FULL_DOMAIN"
