#!/bin/bash
# install_ota_server.sh - Installer OTA Server by PakaWrt

APP_DIR="/opt/ota_server"
DATA_FILE="$APP_DIR/clients.json"
PORT=5000
DOMAIN="pakalolo.me"

BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
RESET="\033[0m"

uninstall_previous_installation() {
    echo "[*] Removing previous install if any..."
    systemctl stop ota_server.service 2>/dev/null
    systemctl disable ota_server.service 2>/dev/null
    rm -f /etc/systemd/system/ota_server.service
    systemctl daemon-reload
    rm -rf "$APP_DIR"
    rm -f /etc/nginx/sites-enabled/ota_server
    rm -f /etc/nginx/sites-available/ota_server
    rm -f /usr/local/bin/menu
}

install_dependencies() {
    echo "[*] Installing dependencies..."
    apt update
    apt install -y python3 python3-pip python3-venv nginx jq
}

setup_directories() {
    mkdir -p "$APP_DIR"
    echo "{}" > "$DATA_FILE"
}

create_flask_app() {
    cat <<EOF > "$APP_DIR/app.py"
from flask import Flask, request, jsonify, send_file
import json
import os

app = Flask(__name__)
DATA_FILE = "$DATA_FILE"

def load_clients():
    if not os.path.exists(DATA_FILE):
        return {}
    with open(DATA_FILE, "r") as f:
        return json.load(f)

def save_clients(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=4)

@app.route("/register", methods=["POST"])
def register():
    mac = request.form.get("mac")
    name = request.form.get("name", "Unknown")
    if not mac:
        return jsonify({"status": "error", "message": "MAC address required"}), 400

    clients = load_clients()
    if mac not in clients:
        clients[mac] = {"name": name, "approved": False}
        save_clients(clients)
        return jsonify({"status": "registered", "approved": False}), 201

    return jsonify({"status": "exists", "approved": clients[mac]["approved"]})

@app.route("/firmware.bin", methods=["GET"])
def firmware():
    mac = request.args.get("mac")
    clients = load_clients()
    if not mac or mac not in clients or not clients[mac]["approved"]:
        return jsonify({"status": "denied"}), 403

    filepath = os.path.join("$APP_DIR", "firmware.bin")
    if not os.path.exists(filepath):
        return jsonify({"status": "error", "message": "Firmware not found"}), 404

    return send_file(filepath, as_attachment=True)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=$PORT)
EOF
}

setup_venv() {
    python3 -m venv "$APP_DIR/venv"
    source "$APP_DIR/venv/bin/activate"
    pip install flask
}

setup_systemd() {
    cat <<EOF > /etc/systemd/system/ota_server.service
[Unit]
Description=OTA Server Flask App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ota_server
    systemctl start ota_server
}

setup_nginx() {
    cat <<EOF > /etc/nginx/sites-available/ota_server
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/ota_server /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx
}

create_admin_menu() {
    cat <<'EOF' > "$APP_DIR/menu.sh"
#!/bin/bash
DATA_FILE="/opt/ota_server/clients.json"

menu() {
    while true; do
        clear
        echo "====== OTA CLIENT MANAGER ======"
        echo "1) List Clients"
        echo "2) Add Client Manually"
        echo "3) Approve Pending Client"
        echo "4) Delete Client"
        echo "5) Exit"
        echo "================================"
        read -p "Select option: " opt

        case $opt in
            1)
                jq '.' "$DATA_FILE"
                read -p "Press enter to continue..." ;;
            2)
                read -p "Enter MAC Address: " mac
                read -p "Enter Client Name: " name
                jq ". + {\"$mac\": {\"name\": \"$name\", \"approved\": true}}" "$DATA_FILE" > "$DATA_FILE.tmp" && mv "$DATA_FILE.tmp" "$DATA_FILE"
                echo "Client added and approved!"
                read -p "Press enter to continue..." ;;
            3)
                pending=($(jq -r 'to_entries[] | select(.value.approved==false) | .key' "$DATA_FILE"))
                if [ ${#pending[@]} -eq 0 ]; then
                    echo "No pending clients."
                else
                    for i in "${!pending[@]}"; do
                        name=$(jq -r ".\"${pending[$i]}\".name" "$DATA_FILE")
                        echo "$((i+1))) ${pending[$i]} - $name"
                    done
                    read -p "Select number to approve: " index
                    sel_mac="${pending[$((index-1))]}"
                    if [ -n "$sel_mac" ]; then
                        jq ".\"$sel_mac\".approved = true" "$DATA_FILE" > "$DATA_FILE.tmp" && mv "$DATA_FILE.tmp" "$DATA_FILE"
                        echo "Client $sel_mac approved."
                    else
                        echo "Invalid selection."
                    fi
                fi
                read -p "Press enter to continue..." ;;
            4)
                clients=($(jq -r 'keys[]' "$DATA_FILE"))
                for i in "${!clients[@]}"; do
                    name=$(jq -r ".\"${clients[$i]}\".name" "$DATA_FILE")
                    echo "$((i+1))) ${clients[$i]} - $name"
                done
                read -p "Select number to delete: " index
                sel_mac="${clients[$((index-1))]}"
                if [ -n "$sel_mac" ]; then
                    jq "del(.\"$sel_mac\")" "$DATA_FILE" > "$DATA_FILE.tmp" && mv "$DATA_FILE.tmp" "$DATA_FILE"
                    echo "Client $sel_mac deleted."
                else
                    echo "Invalid selection."
                fi
                read -p "Press enter to continue..." ;;
            5) exit ;;
            *) echo "Invalid option."; sleep 1 ;;
        esac
    done
}

menu
EOF

    chmod +x "$APP_DIR/menu.sh"
    ln -sf "$APP_DIR/menu.sh" /usr/local/bin/menu
}

main() {
    uninstall_previous_installation
    install_dependencies
    setup_directories
    create_flask_app
    setup_venv
    setup_systemd
    setup_nginx
    create_admin_menu

    echo -e "${BOLD_GREEN}✅ OTA SERVER INSTALLED SUCCESSFULLY!${RESET}"
    echo -e "${BOLD_YELLOW}📋 Manage clients using:${RESET} ${BOLD}/usr/local/bin/menu${RESET}"
}

main
