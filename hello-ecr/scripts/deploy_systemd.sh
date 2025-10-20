##!/usr/bin/env bash
## ==========================================================
## deploy_systemd.sh — Remote deploy on EC2
## What it does:
##   1) Ensure Python + venv
##   2) Unpack hello-ecr.tgz into a timestamped release folder
##   3) Update /home/ubuntu/app/current symlink
##   4) Configure a systemd service and restart it
## ==========================================================
#
#set -euo pipefail
#
#log() { echo "[deploy] $*"; }
#
#APP_ROOT=/home/ubuntu/app
#RELEASES=/home/ubuntu/releases
#PKG=/home/ubuntu/hello-ecr.tgz
#
#log "Installing Python & tools"
#sudo apt-get update -y
#sudo apt-get install -y python3 python3-venv python3-pip
#
#log "Preparing folders"
#mkdir -p "$RELEASES" "$APP_ROOT"
#BUILD_ID=$(date -u +%Y%m%dT%H%M%SZ)
#REL="$RELEASES/$BUILD_ID"
#mkdir -p "$REL"
#
#log "Unpacking artifact: $PKG"
#tar -xzf "$PKG" -C "$REL"
#
#log "Ensuring virtualenv"
#if [[ ! -d "$APP_ROOT/.venv" ]]; then
#  python3 -m venv "$APP_ROOT/.venv"
#  "$APP_ROOT/.venv/bin/pip" -q install --upgrade pip
#fi
#if [[ -f "$REL/requirements.txt" ]]; then
#  log "Installing dependencies"
#  "$APP_ROOT/.venv/bin/pip" -q install -r "$REL/requirements.txt"
#fi
#
#log "Pointing 'current' to new release"
#ln -sfn "$REL" "$APP_ROOT/current"
#
#log "Writing systemd unit"
#sudo bash -c 'cat > /etc/systemd/system/hello-ecr.service <<SVC
#[Unit]
#Description=hello-ecr (auto-deployed)
#After=network.target
#
#[Service]
#User=ubuntu
#WorkingDirectory=/home/ubuntu/app/current
#ExecStart=/home/ubuntu/app/.venv/bin/python app.py
#Restart=always
#RestartSec=5
#
#[Install]
#WantedBy=multi-user.target
#SVC'
#
#log "Restarting service"
#sudo systemctl daemon-reload
#sudo systemctl enable hello-ecr --now
#sudo systemctl restart hello-ecr
#
#log "Keeping only 5 newest releases"
#ls -1dt $RELEASES/* 2>/dev/null | tail -n +6 | xargs -r rm -rf
#
#log "Done "


#!/usr/bin/env bash
# ==========================================================
# deploy_systemd.sh — Remote deploy on EC2 (Amazon Linux 2023)
# What it does:
#   1) Ensure Python + venv (dnf)
#   2) Unpack hello-ecr.tgz into /opt/hello-ecr
#   3) Create/refresh a systemd service and restart it
# Supports:
#   - APP_PORT   (default: 5000)
#   - APP_MODULE (default: app:app) if you use gunicorn
#   - Or run python app.py if you don't want gunicorn
# ==========================================================

set -euo pipefail
log() { echo "[deploy] $*"; }

APP_DIR="/opt/hello-ecr"
PKG="$HOME/hello-ecr.tgz"
SERVICE_NAME="hello-ecr"
APP_PORT="${APP_PORT:-5000}"
APP_MODULE="${APP_MODULE:-}"   # if set, we'll use gunicorn; else run python app.py

# 1) Ensure Python & tools
log "Installing Python 3 and tools (dnf)"
sudo dnf -y install python3 python3-pip python3-virtualenv tar >/dev/null

# 2) Prepare directory and unpack artifact
log "Preparing ${APP_DIR}"
sudo mkdir -p "$APP_DIR"
sudo tar -xzf "$PKG" -C "$APP_DIR" --strip-components=0
sudo chown -R ec2-user:ec2-user "$APP_DIR"

# 3) venv + deps
log "Setting up venv and installing requirements (if any)"
python3 -m venv "$APP_DIR/venv"
source "$APP_DIR/venv/bin/activate"
pip install --upgrade pip >/dev/null 2>&1 || true
if [ -f "$APP_DIR/requirements.txt" ]; then
  pip install -r "$APP_DIR/requirements.txt"
fi

USE_GUNICORN=0
if [ -n "$APP_MODULE" ]; then
  pip install gunicorn
  USE_GUNICORN=1
fi

# 4) systemd unit
log "Writing systemd unit"
if [ "$USE_GUNICORN" -eq 1 ]; then
  EXEC_START="${APP_DIR}/venv/bin/gunicorn --bind 0.0.0.0:${APP_PORT} ${APP_MODULE}"
else
  # Fall back to python app.py (must exist in app root)
  EXEC_START="${APP_DIR}/venv/bin/python ${APP_DIR}/app.py"
fi

sudo bash -c "cat > /etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=hello-ecr service
After=network.target

[Service]
User=ec2-user
WorkingDirectory=${APP_DIR}
Environment=APP_PORT=${APP_PORT}
ExecStart=${EXEC_START}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 5) Reload + enable + restart
log "Restarting ${SERVICE_NAME}"
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}" --now
sudo systemctl restart "${SERVICE_NAME}"

log "Deployed on port ${APP_PORT} "
