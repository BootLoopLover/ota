#!/bin/bash

FLASK_SERVICE_NAME="ota-flask.service"
CLOUDFLARED_SERVICE_NAME="cloudflared-ota.service"
FLASK_APP_DIR="/home/paka/ota-backend"

# ... bagian instalasi python dan flask, setup virtualenv dll

echo "=== Setup systemd service for Flask app ==="
sudo tee "/etc/systemd/system/${FLASK_SERVICE_NAME}" > /dev/null <<EOF
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

echo "=== Setup systemd service for Cloudflared tunnel ==="
sudo tee "/etc/systemd/system/${CLOUDFLARED_SERVICE_NAME}" > /dev/null <<EOF
[Unit]
Description=Cloudflared Tunnel for OTA
After=network.target

[Service]
User=$USER
ExecStart=/usr/local/bin/cloudflared tunnel run ota-tunnel
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Reload systemd daemon and enable services..."
sudo systemctl daemon-reload
sudo systemctl enable --now "$FLASK_SERVICE_NAME"
sudo systemctl enable --now "$CLOUDFLARED_SERVICE_NAME"

echo "Setup completed. Services should be running now."
