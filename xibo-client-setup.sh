#!/usr/bin/env bash

set -euxo pipefail

CMS_URL="http://192.168.101.143"
XIBO_DIR="/opt/xibo"
CONTAINER_NAME="xibo-player"

# =========================================
# Checks
# =========================================

if [[ $EUID -eq 0 ]]; then
    echo "Do not run this script as root."
    echo "Run it as a normal user with sudo access."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required."
    exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"

echo "========================================="
echo "Installing dependencies"
echo "========================================="

sudo apt update

sudo apt install -y \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    bash

# =========================================
# Docker
# =========================================

if ! command -v docker >/dev/null 2>&1; then
    echo "========================================="
    echo "Installing Docker"
    echo "========================================="

    curl -fsSL https://get.docker.com | sudo sh
else
    echo "Docker already installed"
fi

sudo systemctl enable docker
sudo systemctl restart docker

sudo usermod -aG docker "$TARGET_USER"

# =========================================
# Directories
# =========================================

echo "========================================="
echo "Creating directories"
echo "========================================="

sudo mkdir -p "$XIBO_DIR"
sudo chown -R "$TARGET_USER:$TARGET_USER" "$XIBO_DIR"

# =========================================
# Disable sleep/screensaver
# =========================================

echo "========================================="
echo "Disabling sleep and screensaver"
echo "========================================="

sudo systemctl mask \
    sleep.target \
    suspend.target \
    hibernate.target \
    hybrid-sleep.target || true

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.session idle-delay 0 || true
    gsettings set org.gnome.desktop.screensaver lock-enabled false || true
fi

sudo mkdir -p /etc/X11/xorg.conf.d

cat <<EOF | sudo tee /etc/X11/xorg.conf.d/10-monitor.conf >/dev/null
Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
EOF

# =========================================
# Remove old container
# =========================================

echo "========================================="
echo "Removing old container"
echo "========================================="

sudo docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# =========================================
# Pull latest image
# =========================================

echo "========================================="
echo "Pulling Xibo image"
echo "========================================="

sudo docker pull xibosignage/xibo-linux

# =========================================
# Start player
# =========================================

echo "========================================="
echo "Starting Xibo Player"
echo "========================================="

sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network host \
    -v "$XIBO_DIR:/xibo" \
    -e CMS_SERVER="$CMS_URL" \
    xibosignage/xibo-linux

# =========================================
# Done
# =========================================

echo
echo "========================================="
echo "Installation complete"
echo "========================================="
echo
echo "CMS URL: $CMS_URL"
echo
echo "Authorize the display in Xibo CMS."
echo
echo "IMPORTANT:"
echo "You may need to logout/login or reboot"
echo "for docker group permissions to apply."
echo
echo "Container logs:"
echo "sudo docker logs -f $CONTAINER_NAME"
