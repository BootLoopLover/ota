#!/bin/bash

SERVER="https://ota.pakawrt.me"

echo "=== PakaWRT OTA Admin Panel ==="

# Ambil daftar user yang terdaftar
REGISTERED_JSON=$(curl -s "$SERVER/registered")

if [ -z "$REGISTERED_JSON" ] || [ "$REGISTERED_JSON" = "{}" ]; then
  echo "Tidak ada user yang perlu approval."
  exit 0
fi

USER_LIST=($(echo "$REGISTERED_JSON" | jq -r 'keys[]'))

echo "User terdaftar (pending approval):"
for i in "${!USER_LIST[@]}"; do
  username=${USER_LIST[$i]}
  approved=$(echo "$REGISTERED_JSON" | jq -r ".\"$username\".approved")
  status="Pending"
  [ "$approved" == "true" ] && status="Approved"
  echo "$((i+1))) $username - Status: $status"
done

echo -n "Pilih nomor user untuk approve (0 batal): "
read CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
  echo "Input tidak valid."
  exit 1
fi

if [ "$CHOICE" -eq 0 ]; then
  echo "Batal."
  exit 0
fi

INDEX=$((CHOICE - 1))
if [ "$INDEX" -lt 0 ] || [ "$INDEX" -ge "${#USER_LIST[@]}" ]; then
  echo "Nomor pilihan tidak valid."
  exit 1
fi

SELECTED_USER="${USER_LIST[$INDEX]}"

echo "Approve user $SELECTED_USER? (y/n): "
read CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$SELECTED_USER\"}" "$SERVER/approve")
  echo "Response server: $RESPONSE"
else
  echo "Approval dibatalkan."
fi
