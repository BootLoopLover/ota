#!/bin/bash
# Installer OTA Server + Flask + Gunicorn + NGINX + Cloudflare Tunnel
# Author: PakaDev

APP_DIR="/opt/ota_server"
DOMAIN="ota.pakalolo.me"
TUNNEL_NAME="ota-server"

clear
echo "============================================"
echo "         OTA SERVER INSTALLER FINAL         "
echo "        (Flask + Gunicorn + NGINX + CF)     "
echo "============================================"

# 1. Install dependencies
echo "[+] Installing dependencies..."
apt update -y
apt install -y python3 python3-pip python3-venv nginx jq curl cloudflared

# 2. Create app directory
mkdir -p "$APP_DIR"
cd "$APP_DIR" || exit 1

# 3. Setup Python virtualenv
python3 -m venv venv
source venv/bin/activate
pip install flask gunicorn

# 4. Create Flask app
cat > app.py <<'EOF'
from flask import Flask, request, send_from_directory, jsonify
import os
import json
app = Flask(__name__)

CLIENT_DB = "clients.json"
FIRMWARE_DIR = "firmwares"

os.makedirs(FIRMWARE_DIR, exist_ok=True)
if not os.path.exists(CLIENT_DB):
    with open(CLIENT_DB, "w") as f:
        json.dump([], f)

@app.route("/register", methods=["GET"])
def register():
    name = request.args.get("name", "")
    mac = request.args.get("mac", "")
    if not name or not mac:
        return jsonify({"error": "name and mac required"}), 400
    with open(CLIENT_DB, "r+") as f:
        clients = json.load(f)
        if not any(c["mac"] == mac for c in clients):
            clients.append({"name": name, "mac": mac})
            f.seek(0)
            json.dump(clients, f, indent=2)
    return jsonify({"message": "registered", "name": name, "mac": mac})

@app.route("/firmware.bin", methods=["GET"])
def firmware():
    name = request.args.get("name", "")
    mac = request.args.get("mac", "")
    file = request.args.get("file", "firmware.bin")
    if not os.path.exists(os.path.join(FIRMWARE_DIR, file)):
        return jsonify({"error": "firmware not found"}), 404
    return send_from_directory(FIRMWARE_DIR, file)
EOF

# 5. Systemd service for Gunicorn
echo "[+] Setting up Gunicorn service..."
cat > /etc/systemd/system/ota_server.service <<EOF
[Unit]
Description=OTA Server Flask App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn -b 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable ota_server
systemctl start ota_server

# 6. NGINX reverse proxy
echo "[+] Setting up NGINX..."
cat > /etc/nginx/sites-available/ota_server <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/ota_server /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# 7. Cloudflare Tunnel Setup
echo "[+] Setting up Cloudflare Tunnel..."
cloudflared service install || true

cloudflared tunnel list | grep -q "$TUNNEL_NAME"
if [ $? -ne 0 ]; then
    cloudflared tunnel create "$TUNNEL_NAME"
fi

cat > ~/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_NAME
credentials-file: /root/.cloudflared/${TUNNEL_NAME}.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF

cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN"
systemctl enable cloudflared
systemctl restart cloudflared

# 8. Client manager
echo "[+] Creating CLI: manage_clients.sh"
cat > /usr/local/bin/manage_clients.sh <<EOF
#!/bin/bash
cd $APP_DIR || exit
CLIENT_DB="clients.json"

case "\$1" in
  list)
    jq . \$CLIENT_DB
    ;;
  delete)
    MAC="\$2"
    jq 'del(.[] | select(.mac == "'\$MAC'"))' \$CLIENT_DB > tmp && mv tmp \$CLIENT_DB
    ;;
  clear)
    echo "[]" > \$CLIENT_DB
    ;;
  *)
    echo "Usage: \$0 {list|delete <mac>|clear}"
    ;;
esac
EOF
chmod +x /usr/local/bin/manage_clients.sh

# 9. Final output
echo "============================================"
echo "[✓] OTA Server has been installed!"
echo "Flask App Directory : $APP_DIR"
echo "Firmware Directory  : $APP_DIR/firmwares"
echo "Client DB           : $APP_DIR/clients.json"
echo "Cloudflare Tunnel   : $DOMAIN"
echo "Client CLI          : manage_clients.sh list/delete/clear"
echo "============================================"
