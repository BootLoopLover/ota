#!/bin/bash

APP_DIR="/opt/ota_server"
FIRMWARE_DIR="/home/paka/Desktop/Firmware"
FLASK_PORT=8080
NGROK_BIN="/usr/bin/ngrok"
SESSION="ota_server"

# Hentikan session lama kalau ada
tmux has-session -t $SESSION 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Menghentikan session tmux lama..."
    tmux kill-session -t $SESSION
fi

echo "Membuat session tmux baru: $SESSION"

tmux new-session -d -s $SESSION -n flask "cd $APP_DIR && python app.py"
sleep 3
tmux new-window -t $SESSION:1 -n ngrok "$NGROK_BIN http $FLASK_PORT"

echo "Menunggu ngrok tunnel siap..."

NGROK_URL=""
TIMEOUT=20
COUNT=0

while [[ -z "$NGROK_URL" && $COUNT -lt $TIMEOUT ]]; do
    sleep 1
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null \
        | grep -o 'https://[a-zA-Z0-9.-]*.ngrok-free.app' | head -n1)
    ((COUNT++))
done

if [[ -n "$NGROK_URL" ]]; then
    echo "✅ OTA Server Aktif di: $NGROK_URL"
    echo "🔗 Contoh URL download:"
    for f in "$FIRMWARE_DIR"/*.bin; do
        file_name=$(basename "$f")
        echo "   - $NGROK_URL/firmware/$file_name"
    done
else
    echo "❌ Gagal mendapatkan URL ngrok setelah $TIMEOUT detik."
fi

echo ""
echo "Pantau proses dengan:"
echo "  tmux attach-session -t $SESSION"
echo ""
echo "Hentikan server dengan:"
echo "  tmux kill-session -t $SESSION"
