#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip

APP_ROOT=/home/ubuntu/app
RELEASES=/home/ubuntu/releases
mkdir -p "$RELEASES" "$APP_ROOT"

BUILD_ID=$(date -u +%Y%m%dT%H%M%SZ)
REL="$RELEASES/$BUILD_ID"
mkdir -p "$REL"
tar -xzf /home/ubuntu/hello-ecr.tgz -C "$REL"

if [[ ! -d "$APP_ROOT/.venv" ]]; then
  python3 -m venv "$APP_ROOT/.venv"
  "$APP_ROOT/.venv/bin/pip" -q install --upgrade pip
fi
if [[ -f "$REL/requirements.txt" ]]; then
  "$APP_ROOT/.venv/bin/pip" -q install -r "$REL/requirements.txt"
fi

ln -sfn "$REL" "$APP_ROOT/current"

sudo bash -c 'cat > /etc/systemd/system/hello-ecr.service <<SVC
[Unit]
Description=hello-ecr
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app/current
ExecStart=/home/ubuntu/app/.venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC'

sudo systemctl daemon-reload
sudo systemctl enable hello-ecr --now
sudo systemctl restart hello-ecr

# keep last 5 releases
ls -1dt $RELEASES/* 2>/dev/null | tail -n +6 | xargs -r rm -rf
