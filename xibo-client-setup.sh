#!/usr/bin/env bash

set -e

CMS_URL="http://192.168.101.143"

echo "========================================="
echo "Installing Docker"
echo "========================================="

curl -fsSL https://get.docker.com | sh

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

mkdir -p /opt/xibo


echo "========================================="
echo "Disabling sleep and screensaver"
echo "========================================="

sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.session idle-delay 0 || true
    gsettings set org.gnome.desktop.screensaver lock-enabled false || true
fi

sudo mkdir -p /etc/X11/xorg.conf.d

sudo tee /etc/X11/xorg.conf.d/10-monitor.conf > /dev/null <<EOF
Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
EOF


echo "========================================="
echo "Removing old player container if exists"
echo "========================================="

docker rm -f xibo-player 2>/dev/null || true


echo "========================================="
echo "Starting Xibo Player"
echo "========================================="

docker run -d \
  --name xibo-player \
  --restart unless-stopped \
  --network host \
  -v /opt/xibo:/xibo \
  -e CMS_SERVER="$CMS_URL" \
  xibosignage/xibo-linux


echo "========================================="
echo "DONE"
echo "========================================="

echo "Now open Xibo CMS and authorize the display."
echo "CMS URL: $CMS_URL"