#!/usr/bin/env bash
# ==========================================================
# deploy_systemd.sh — Remote deploy on EC2
# What it does:
#   1) Ensure Python + venv
#   2) Unpack hello-ecr.tgz into a timestamped release folder
#   3) Update /home/ubuntu/app/current symlink
#   4) Configure a systemd service and restart it
# ==========================================================

set -euo pipefail

log() { echo "[deploy] $*"; }

APP_ROOT=/home/ubuntu/app
RELEASES=/home/ubuntu/releases
PKG=/home/ubuntu/hello-ecr.tgz

log "Installing Python & tools"
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip

log "Preparing folders"
mkdir -p "$RELEASES" "$APP_ROOT"
BUILD_ID=$(date -u +%Y%m%dT%H%M%SZ)
REL="$RELEASES/$BUILD_ID"
mkdir -p "$REL"

log "Unpacking artifact: $PKG"
tar -xzf "$PKG" -C "$REL"

log "Ensuring virtualenv"
if [[ ! -d "$APP_ROOT/.venv" ]]; then
  python3 -m venv "$APP_ROOT/.venv"
  "$APP_ROOT/.venv/bin/pip" -q install --upgrade pip
fi
if [[ -f "$REL/requirements.txt" ]]; then
  log "Installing dependencies"
  "$APP_ROOT/.venv/bin/pip" -q install -r "$REL/requirements.txt"
fi

log "Pointing 'current' to new release"
ln -sfn "$REL" "$APP_ROOT/current"

log "Writing systemd unit"
sudo bash -c 'cat > /etc/systemd/system/hello-ecr.service <<SVC
[Unit]
Description=hello-ecr (auto-deployed)
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

log "Restarting service"
sudo systemctl daemon-reload
sudo systemctl enable hello-ecr --now
sudo systemctl restart hello-ecr

log "Keeping only 5 newest releases"
ls -1dt $RELEASES/* 2>/dev/null | tail -n +6 | xargs -r rm -rf

log "Done ✅"
