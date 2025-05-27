#!/bin/bash
APP_DIR="/opt/ota_server"
FIRMWARE_DIR="/opt/ota_server/firmware"
FLASK_PORT=8080
NGROK_BIN="/usr/bin/ngrok"
SESSION="ota_server"

cd "$APP_DIR"

# Matikan session lama jika ada
tmux has-session -t $SESSION 2>/dev/null && tmux kill-session -t $SESSION
echo "📦 Menjalankan server OTA di tmux session: $SESSION"

# Jalankan Flask dan Ngrok dalam tmux
tmux new-session -d -s $SESSION -n flask "cd $APP_DIR && python3 app.py"
sleep 3
tmux new-window -t $SESSION:1 -n ngrok "$NGROK_BIN http $FLASK_PORT"
sleep 5

# Coba ambil URL Ngrok
echo "Menunggu ngrok tunnel siap..."
NGROK_URL=""

for i in {1..30}; do
    sleep 2
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels \
        | grep -o 'https://[a-zA-Z0-9.-]*\.ngrok-free\.app' | head -n1)

    if [[ -n "$NGROK_URL" ]]; then
        break
    fi
done

# Tampilkan hasil
if [[ -n "$NGROK_URL" ]]; then
    echo ""
    echo "✅ OTA Server aktif di: $NGROK_URL"
    echo "📦 Firmware yang tersedia:"
    for f in "$FIRMWARE_DIR"/*.bin; do
        fn=$(basename "$f")
        echo "   - $NGROK_URL/firmware/$fn?token=YOUR_TOKEN"
    done
else
    echo "❌ Gagal mendapatkan URL ngrok setelah 60 detik."
    echo "🔍 Coba periksa apakah ngrok sudah autentikasi (add-authtoken) dan Flask berjalan dengan benar."
    echo "🔧 Debug: curl http://127.0.0.1:4040/api/tunnels"
fi

echo ""
echo "Pantau proses dengan:  tmux attach-session -t $SESSION"
echo "Hentikan server dengan: tmux kill-session -t $SESSION"
