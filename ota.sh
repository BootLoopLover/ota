#!/bin/bash

set -e

echo "🔧 Memulai instalasi OTA Server untuk PakaWrt..."

echo "📦 Menginstall dependensi sistem..."
sudo apt update
sudo apt install -y python3 python3-pip nginx unzip curl

echo "🐍 Menginstall Flask..."
pip3 install flask

echo "📁 Menyiapkan direktori OTA..."
sudo mkdir -p /opt/ota_server/firmware
sudo chown -R $USER:$USER /opt/ota_server

echo "📝 Menulis file server.py..."
cat <<EOF > /opt/ota_server/server.py
from flask import Flask, send_from_directory, request, redirect, jsonify
import os, json

app = Flask(__name__)
FIRMWARE_FOLDER = "/opt/ota_server/firmware"
USERS_FILE = "/opt/ota_server/registered.json"

@app.route("/")
def home():
    files = os.listdir(FIRMWARE_FOLDER)
    links = "".join(
        f'<li><a href="/firmware/{f}" target="_blank">{f}</a></li>' for f in files
    )
    return f\"\"\"
    <h2>📡 OTA Server PakaWrt</h2>
    <p>Pilih file firmware untuk flashing setelah register.</p>
    <form action="/register" method="post">
        Nama: <input name="name" required><br>
        <input type="submit" value="Daftar 🔐">
    </form>
    <ul>{links}</ul>
    \"\"\"

@app.route("/firmware/<filename>")
def download(filename):
    return send_from_directory(FIRMWARE_FOLDER, filename)

@app.route("/register", methods=["POST"])
def register():
    name = request.form.get("name")
    if not name:
        return "❌ Nama tidak valid", 400
    users = []
    if os.path.exists(USERS_FILE):
        with open(USERS_FILE) as f:
            users = json.load(f)
    user = {"name": name, "approved": False}
    users.append(user)
    with open(USERS_FILE, "w") as f:
        json.dump(users, f, indent=2)
    return f"✅ Terima kasih {name}, tunggu persetujuan admin."

@app.route("/admin")
def admin():
    with open(USERS_FILE) as f:
        users = json.load(f)
    user_list = "".join(
        f'<li>{u["name"]} - {"✅" if u["approved"] else "<a href=\'/approve?name="+u["name"]+"\'>Setujui</a>"}</li>'
        for u in users
    )
    return f"<h2>🛠️ Panel Admin</h2><ul>{user_list}</ul>"

@app.route("/approve")
def approve():
    name = request.args.get("name")
    with open(USERS_FILE) as f:
        users = json.load(f)
    for u in users:
        if u["name"] == name:
            u["approved"] = True
    with open(USERS_FILE, "w") as f:
        json.dump(users, f, indent=2)
    return redirect("/admin")

@app.route("/user")
def user_script():
    return send_from_directory("/opt/ota_server", "user.sh")
    
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

echo "📜 Membuat script user.sh..."
cat <<EOF > /opt/ota_server/user.sh
#!/bin/sh
echo "🚀 OTA PakaWrt - Registrasi"
echo "🌐 Daftar di https://ota.pakawrt.me/ untuk mulai flashing firmware"
EOF
chmod +x /opt/ota_server/user.sh

echo "🌐 Mengatur systemd service untuk Flask server..."
cat <<EOF | sudo tee /etc/systemd/system/ota-server.service > /dev/null
[Unit]
Description=OTA Server Flask
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/ota_server/server.py
WorkingDirectory=/opt/ota_server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable ota-server
sudo systemctl start ota-server

echo "☁️ Mengunduh Cloudflared..."
sudo mkdir -p /usr/local/bin
curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
sudo install -m 755 cloudflared /usr/local/bin/cloudflared

echo "📡 Membuat Cloudflare Tunnel..."
cloudflared service install
cloudflared tunnel login
cloudflared tunnel create ota-tunnel
cloudflared tunnel route dns ota-tunnel ota.pakawrt.me

echo "📝 Membuat config Cloudflare Tunnel..."
mkdir -p ~/.cloudflared
cat <<EOF > ~/.cloudflared/config.yml
tunnel: ota-tunnel
credentials-file: /home/$USER/.cloudflared/ota-tunnel.json

ingress:
  - hostname: ota.pakawrt.me
    service: http://localhost:5000
  - service: http_status:404
EOF

echo "🔁 Setup systemd untuk Tunnel..."
cat <<EOF | sudo tee /etc/systemd/system/cloudflared.service > /dev/null
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
ExecStart=/usr/local/bin/cloudflared tunnel --config /home/$USER/.cloudflared/config.yml run
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

echo "✅ OTA Server berhasil di-setup!"
echo "🌐 Akses OTA Server di: https://ota.pakawrt.me"
