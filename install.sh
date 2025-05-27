#!/bin/bash
set -e

echo ""
echo "=========================================="
echo "🔧 OTA Server Installer for OpenWrt"
echo "📦 Dengan sistem approval token"
echo "=========================================="
echo ""

# Persiapan
PKG_LIST="python3 python3-pip tmux curl jq"
NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-stable-linux-arm64.tgz"
INSTALL_DIR="/root/ota_server"
FIRMWARE_DIR="/root/firmware"
NGROK_BIN="/usr/bin/ngrok"

# Cek dan install paket
echo "🔍 Memeriksa & menginstal dependencies..."
opkg update
for pkg in $PKG_LIST; do
    opkg install "$pkg" || true
done

# Install Flask
echo "📦 Menginstal Flask..."
pip3 install flask --no-cache-dir

# Download Ngrok
if [ ! -f "$NGROK_BIN" ]; then
    echo "⬇️  Mengunduh ngrok..."
    wget -O /tmp/ngrok.tgz "$NGROK_URL"
    tar -xvzf /tmp/ngrok.tgz -C /tmp
    mv /tmp/ngrok "$NGROK_BIN"
    chmod +x "$NGROK_BIN"
    rm /tmp/ngrok.tgz
fi

# Siapkan direktori
mkdir -p "$INSTALL_DIR"
mkdir -p "$FIRMWARE_DIR"
cd "$INSTALL_DIR"

# Simpan file backend `app.py`
cat << 'EOF' > app.py
from flask import Flask, send_file, jsonify, request
import os, json

app = Flask(__name__)
FIRMWARE_FOLDER = "/root/firmware"
APPROVED_TOKENS_FILE = "/root/ota_server/approved_tokens.json"

def load_approved_tokens():
    if os.path.exists(APPROVED_TOKENS_FILE):
        with open(APPROVED_TOKENS_FILE, "r") as f:
            return json.load(f)
    return {}

def save_approved_tokens(tokens):
    with open(APPROVED_TOKENS_FILE, "w") as f:
        json.dump(tokens, f, indent=2)

@app.route("/")
def index():
    return "✅ OTA Server is running with token authentication."

@app.route("/register", methods=["POST"])
def register():
    device_id = request.form.get("device_id")
    if not device_id:
        return jsonify({"error": "device_id is required"}), 400
    token = os.urandom(4).hex()
    tokens = load_approved_tokens()
    tokens[token] = {"device_id": device_id, "approved": False}
    save_approved_tokens(tokens)
    return jsonify({"message": "Waiting for approval", "token": token}), 202

@app.route("/approve", methods=["POST"])
def approve_token():
    token = request.form.get("token")
    tokens = load_approved_tokens()
    if token in tokens:
        tokens[token]["approved"] = True
        save_approved_tokens(tokens)
        return jsonify({"message": f"Token {token} approved."})
    return jsonify({"error": "Token not found."}), 404

@app.route("/firmware/<filename>")
def serve_firmware(filename):
    token = request.args.get("token")
    if not token:
        return jsonify({"error": "Token required."}), 403
    tokens = load_approved_tokens()
    if token not in tokens or not tokens[token]["approved"]:
        return jsonify({"error": "Unauthorized or token not approved."}), 401
    filepath = os.path.join(FIRMWARE_FOLDER, filename)
    if os.path.exists(filepath):
        return send_file(filepath, as_attachment=True)
    return jsonify({"error": "Firmware not found"}), 404

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

# Token database
echo "{}" > approved_tokens.json

# Admin CLI
cat << 'EOF' > admin-cli.sh
#!/bin/bash
TOKEN_FILE="/root/ota_server/approved_tokens.json"

function list_tokens() {
    echo "🧾 Token List:"
    jq '.' $TOKEN_FILE
}

function approve_token() {
    read -p "Masukkan token yang ingin disetujui: " token
    jq "if .[\"$token\"] then .[\"$token\"].approved = true | . else . end" "$TOKEN_FILE" > tmp.json && mv tmp.json "$TOKEN_FILE"
    echo "✅ Token $token disetujui."
}

while true; do
    echo ""
    echo "====== OTA ADMIN MENU ======"
    echo "1. Lihat semua token"
    echo "2. Approve token"
    echo "3. Keluar"
    read -p "Pilih: " pilihan

    case $pilihan in
        1) list_tokens ;;
        2) approve_token ;;
        3) exit ;;
        *) echo "Pilihan tidak valid." ;;
    esac
done
EOF
chmod +x admin-cli.sh

# Server launcher
cat << 'EOF' > ota-server.sh
#!/bin/bash
APP_DIR="/root/ota_server"
FIRMWARE_DIR="/root/firmware"
FLASK_PORT=5000
NGROK_BIN="/usr/bin/ngrok"
SESSION="ota_server"

cd "$APP_DIR"

tmux has-session -t $SESSION 2>/dev/null && tmux kill-session -t $SESSION
echo "📦 Menjalankan server OTA di tmux session: $SESSION"

tmux new-session -d -s $SESSION -n flask "cd $APP_DIR && python3 app.py"
sleep 3
tmux new-window -t $SESSION:1 -n ngrok "$NGROK_BIN http $FLASK_PORT"

echo "Menunggu ngrok tunnel siap..."
NGROK_URL=""
for i in {1..20}; do
    sleep 1
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels \
        | grep -o 'https://[a-zA-Z0-9.-]*.ngrok-free.app' | head -n1)
    [[ -n "$NGROK_URL" ]] && break
done

if [[ -n "$NGROK_URL" ]]; then
    echo "✅ OTA Server aktif di: $NGROK_URL"
    echo "📦 Firmware yang tersedia:"
    for f in "$FIRMWARE_DIR"/*.bin; do
        fn=$(basename "$f")
        echo "   - $NGROK_URL/firmware/$fn?token=YOUR_TOKEN"
    done
else
    echo "❌ Gagal mendapatkan URL ngrok."
fi

echo ""
echo "Pantau tmux dengan: tmux attach-session -t $SESSION"
EOF
chmod +x ota-server.sh

echo ""
echo "✅ Instalasi selesai!"
echo "📂 Firmware folder : /root/firmware"
echo "🚀 Jalankan server : bash /root/ota_server/ota-server.sh"
echo "🛠️ Admin approval  : bash /root/ota_server/admin-cli.sh"

