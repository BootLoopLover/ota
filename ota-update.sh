#!/bin/bash

set -e

# Konfigurasi domain kamu
DOMAIN="ota.pakalolo.me"
OTA_DIR="/opt/ota_server"
FIRMWARE_DIR="$OTA_DIR/firmware"
PYTHON_ENV="$OTA_DIR/venv"

stop_ngrok() {
    echo "[INFO] Mencari dan menghentikan ngrok di port 8000 jika ada..."
    PIDS=$(lsof -ti tcp:8000)
    if [ -n "$PIDS" ]; then
        echo "[INFO] Menemukan ngrok/ proses lain di port 8000, PID: $PIDS"
        kill $PIDS
        sleep 2
        echo "[INFO] Proses di port 8000 sudah dihentikan."
    else
        echo "[INFO] Tidak ada proses di port 8000."
    fi
}

echo "[INFO] Membuat direktori OTA..."
sudo mkdir -p "$FIRMWARE_DIR"
sudo chown -R $USER:$USER "$OTA_DIR"

echo "[INFO] Menginstal dependency (Python + Flask + NGINX)..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv nginx

echo "[INFO] Membuat virtualenv dan instal Flask..."
python3 -m venv "$PYTHON_ENV"
source "$PYTHON_ENV/bin/activate"
pip install flask
deactivate

echo "[INFO] Membuat app.py OTA server..."
cat > "$OTA_DIR/app.py" << 'EOF'
from flask import Flask, send_from_directory
import os
import signal
import sys
import threading
import time

app = Flask(__name__)
FIRMWARE_FOLDER = "/opt/ota_server/firmware"

@app.route("/")
def home():
    try:
        files = os.listdir(FIRMWARE_FOLDER)
    except FileNotFoundError:
        files = []
    links = "".join(
        f'<li><a href="/firmware/{filename}" target="_blank">{filename}</a></li>'
        for filename in files
    )
    return f"""
    <h2>🔧 OTA Server Aktif (Tanpa Token)</h2>
    <p>Silakan unduh firmware dari link berikut:</p>
    <ul>
        {links}
    </ul>
    """

@app.route("/firmware/<filename>")
def get_firmware(filename):
    return send_from_directory(FIRMWARE_FOLDER, filename)

def signal_handler(sig, frame):
    print("\n[INFO] Server dihentikan dengan aman. Keluar.")
    sys.exit(0)

def auto_shutdown(timeout=600):
    print(f"[INFO] Server akan berhenti otomatis setelah {timeout} detik.")
    time.sleep(timeout)
    print("[INFO] Waktu habis. Server dimatikan otomatis.")
    os._exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    threading.Thread(target=auto_shutdown, daemon=True).start()
    print("[INFO] OTA Server aktif di http://0.0.0.0:8000")
    app.run(host="0.0.0.0", port=8000)
EOF

echo "[INFO] Membuat systemd service untuk Flask OTA..."
sudo tee /etc/systemd/system/ota-server.service > /dev/null << EOF
[Unit]
Description=OTA Flask Server
After=network.target

[Service]
User=$USER
WorkingDirectory=$OTA_DIR
ExecStart=$PYTHON_ENV/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] Menyalakan layanan ota-server..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable ota-server
sudo systemctl start ota-server

echo "[INFO] Konfigurasi NGINX untuk domain $DOMAIN..."
sudo tee /etc/nginx/sites-available/ota > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/ota /etc/nginx/sites-enabled/ota
sudo nginx -t && sudo systemctl reload nginx

echo ""
echo "[✅ SELESAI] OTA Server aktif di http://$DOMAIN"
echo "📂 Folder firmware: $FIRMWARE_DIR"
echo "➡ Tambahkan file .bin ke situ agar bisa diunduh."
