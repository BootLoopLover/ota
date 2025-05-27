#!/bin/bash

FIRMWARE_DIR="/home/paka/Desktop/Firmware"
APPROVAL_FILE="$FIRMWARE_DIR/approved.json"
SERVER_URL="http://127.0.0.1:8080"

echo "=== OTA ADMIN PANEL ==="
select bin in $(ls $FIRMWARE_DIR/*.bin 2>/dev/null | xargs -n1 basename); do
    echo "Masukkan token approval untuk $bin:"
    read -p "Token: " token
    curl -s -X POST "$SERVER_URL/register" -H "Content-Type: application/json" \
         -d "{\"filename\":\"$bin\", \"token\":\"$token\"}" | jq
    echo "✔ Token $token diset untuk $bin"
    break
done
