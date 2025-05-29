#!/bin/bash

set -e

# Ganti ini sesuai kebutuhan
DOMAIN="ota.pakalolo.me"
TUNNEL_NAME="ota-tunnel"
CLOUDFLARE_CRED_DIR="$HOME/.cloudflared"
FLASK_APP_DIR="$HOME/ota-backend"
FLASK_SERVICE_NAME="ota-flask.service"
TUNNEL_SERVICE_NAME="cloudflared-${TUNNEL_NAME}.service"
NGINX_CONF_PATH="/etc/nginx/sites-available/${DOMAIN}.conf"

echo "=== Install dependencies ==="
sudo apt update
sudo apt install -y nginx python3 python3-venv python3-pip

echo "=== Setup Flask app ==="
mkdir -p "$FLASK_APP_DIR"
cat > "$FLASK_APP_DIR/server.py" <<'EOF'
from flask import Flask, request, jsonify, abort
import json
import os

app = Flask(__name__)
REG_FILE = 'registered.json'

if not os.path.exists(REG_FILE):
    with open(REG_FILE, 'w') as f:
        json.dump({}, f)

def load_registered():
    with open(REG_FILE, 'r') as f:
        return json.load(f)

def save_registered(data):
    with open(REG_FILE, 'w') as f:
        json.dump(data, f, indent=2)

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    if not data or 'user' not in data:
        return jsonify({'error': 'Missing user field'}), 400
    registered = load_registered()
    user = data['user']
    if user in registered:
        return jsonify({'message': 'Already registered', 'approved': registered[user]['approved']})
    registered[user] = {'approved': False}
    save_registered(registered)
    return jsonify({'message': 'Registered, pending approval', 'approved': False})

@app.route('/approve/<user>', methods=['POST'])
def approve(user):
    registered = load_registered()
    if user not in registered:
        return jsonify({'error': 'User not found'}), 404
    registered[user]['approved'] = True
    save_registered(registered)
    return jsonify({'message': f'User {user} approved'})

@app.route('/firmware.bin')
def firmware():
    user = request.args.get('user')
    if not user:
        abort(403)
    registered = load_registered()
    if user not in registered or not registered[user]['approved']:
        abort(403)
    # Ganti path firmware bin di sini
    firmware_path = 'firmware.bin'
    if not os.path.exists(firmware_path):
        abort(404)
    return app.send_static_file(firmware_path)

@app.route('/')
def index():
    return "OTA Server Running"

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
EOF

cd "$FLASK_APP_DIR"
python3 -m venv venv
source venv/bin/activate
pip install flask
deactivate

echo "=== Setup systemd service for Flask app ==="
cat > "/etc/systemd/system/${FLASK_SERVICE_NAME}" <<EOF
[Unit]
Description=OTA Flask Backend
After=network.target

[Service]
User=$USER
WorkingDirectory=$FLASK_APP_DIR
ExecStart=$FLASK_APP_DIR/venv/bin/python $FLASK_APP_DIR/server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "$FLASK_SERVICE_NAME"

echo "=== Setup NGINX reverse proxy ==="
sudo tee "$NGINX_CONF_PATH" > /dev/null <<EOF
server {
    listen 127.0.0.1:8080;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
    }
}
EOF

sudo ln -sf "$NGINX_CONF_PATH" /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo "=== Install cloudflared ==="
if ! command -v cloudflared &> /dev/null; then
    echo "Installing cloudflared..."
    curl -L -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
fi

echo "=== Setup Cloudflare Tunnel ==="
mkdir -p "$CLOUDFLARE_CRED_DIR"

# Buat tunnel jika belum ada (ganti sesuai instruksi Cloudflare)
if [ ! -f "$CLOUDFLARE_CRED_DIR/${TUNNEL_NAME}.json" ]; then
    echo "Silakan buat tunnel di https://dash.cloudflare.com dan download credential json ke:"
    echo "$CLOUDFLARE_CRED_DIR/${TUNNEL_NAME}.json"
    echo "Setelah itu jalankan ulang skrip ini."
    exit 1
fi

cat > "$HOME/${TUNNEL_NAME}.yml" <<EOF
tunnel: $(basename "$CLOUDFLARE_CRED_DIR/${TUNNEL_NAME}.json" .json)
credentials-file: $CLOUDFLARE_CRED_DIR/${TUNNEL_NAME}.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:8080
  - service: http_status:404
EOF

echo "=== Setup systemd service for cloudflared tunnel ==="
cat > "/etc/systemd/system/${TUNNEL_SERVICE_NAME}" <<EOF
[Unit]
Description=Cloudflare Tunnel $TUNNEL_NAME
After=network.target

[Service]
User=$USER
ExecStart=/usr/bin/cloudflared tunnel run --config $HOME/${TUNNEL_NAME}.yml $TUNNEL_NAME
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "$TUNNEL_SERVICE_NAME"

echo "=== Setup selesai! ==="
echo "- Flask berjalan di http://127.0.0.1:5000"
echo "- NGINX proxy di http://127.0.0.1:8080"
echo "- Cloudflare Tunnel aktif untuk $DOMAIN"
echo ""
echo "Gunakan endpoint POST /register dengan JSON {\"user\": \"nama_user\"} untuk registrasi."
echo "Admin bisa approve user dengan POST ke /approve/<user>."
echo "User yang disetujui bisa download firmware dengan akses /firmware.bin?user=nama_user"
