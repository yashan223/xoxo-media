#!/bin/bash

# Jellyfin & qBittorrent Auto-Install Script for Ubuntu VPS
# This script installs Jellyfin and qBittorrent with shared media directory

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
MEDIA_DIR="/var/media/jellyfin"
QBIT_DOWNLOAD_DIR="${MEDIA_DIR}/downloads"
QBIT_USER="qbittorrent"
QBIT_PORT=8080
JELLYFIN_PORT=8096

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jellyfin & qBittorrent Installation${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Function to wait for apt locks
wait_for_apt() {
    echo -e "${YELLOW}Checking for apt locks...${NC}"
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo -e "${YELLOW}Waiting for other apt processes to finish...${NC}"
        sleep 3
    done
}

# Update system
echo -e "\n${YELLOW}[1/7] Updating system packages...${NC}"
wait_for_apt
apt-get update
apt-get upgrade -y

# Install dependencies
wait_for_apt
echo -e "\n${YELLOW}[2/7] Installing dependencies...${NC}"
apt-get install -y curl gnupg software-properties-common apt-transport-https

# Install Jellyfin
echo -e "\n${YELLOW}[3/7] Installing Jellyfin...${NC}"

# Add Jellyfin repository
curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg
echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/ubuntu $( lsb_release -c -s ) main" | tee /etc/apt/sources.list.d/jellyfin.list
wait_for_apt

apt-get update
apt-get install -y jellyfin

# Unmask, start and enable Jellyfin
systemctl unmask jellyfin 2>/dev/null || true
systemctl start jellyfin
systemctl enable jellyfin

echo -e "${GREEN}✓ Jellyfin installed successfully${NC}"

wait_for_apt
add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
wait_for_apt
echo -e "\n${YELLOW}[4/7] Installing qBittorrent-nox...${NC}"
add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
apt-get update
apt-get install -y qbittorrent-nox

echo -e "${GREEN}✓ qBittorrent-nox installed successfully${NC}"

# Create media directories
echo -e "\n${YELLOW}[5/7] Creating media directories...${NC}"
mkdir -p "${MEDIA_DIR}"
mkdir -p "${QBIT_DOWNLOAD_DIR}"
mkdir -p "${MEDIA_DIR}/movies"
mkdir -p "${MEDIA_DIR}/tv-shows"
mkdir -p "${MEDIA_DIR}/music"

# Create qBittorrent user
echo -e "\n${YELLOW}[6/7] Configuring qBittorrent...${NC}"
if ! id "${QBIT_USER}" &>/dev/null; then
    # Check if group exists
    if getent group "${QBIT_USER}" &>/dev/null; then
        useradd -r -m -d /home/${QBIT_USER} -s /usr/sbin/nologin -g "${QBIT_USER}" "${QBIT_USER}"
    else
        useradd -r -m -d /home/${QBIT_USER} -s /usr/sbin/nologin "${QBIT_USER}"
    fi
    echo -e "${GREEN}✓ User '${QBIT_USER}' created${NC}"
else
    echo -e "${YELLOW}User '${QBIT_USER}' already exists, skipping creation${NC}"
fi

# Set permissions
chown -R ${QBIT_USER}:${QBIT_USER} "${MEDIA_DIR}"
chmod -R 775 "${MEDIA_DIR}"

# Add jellyfin user to qbittorrent group
usermod -a -G ${QBIT_USER} jellyfin

# Create qBittorrent config directory first
QBIT_CONFIG_DIR="/home/${QBIT_USER}/.config/qBittorrent"
mkdir -p "${QBIT_CONFIG_DIR}"

# Create qBittorrent systemd service
cat > /etc/systemd/system/qbittorrent-nox.service <<EOF
[Unit]
Description=qBittorrent-nox
After=network.target

[Service]
Type=simple
User=${QBIT_USER}
Group=${QBIT_USER}
UMask=002
ExecStart=/usr/bin/qbittorrent-nox --webui-port=${QBIT_PORT}
Restart=on-failure
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Stop qBittorrent if running to apply config
systemctl stop qbittorrent-nox 2>/dev/null || true

# Configure qBittorrent settings
cat > "${QBIT_CONFIG_DIR}/qBittorrent.conf" <<EOF
[LegalNotice]
Accepted=true

[Preferences]
WebUI\Port=${QBIT_PORT}
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
Downloads\SavePath=${QBIT_DOWNLOAD_DIR}
Downloads\TempPath=${QBIT_DOWNLOAD_DIR}/temp
WebUI\LocalHostAuth=false
Connection\PortRangeMin=6881
Connection\UPnP=false
EOF

chown -R ${QBIT_USER}:${QBIT_USER} "${QBIT_CONFIG_DIR}"

# Enable and start services
echo -e "\n${YELLOW}[7/7] Starting services...${NC}"
systemctl unmask qbittorrent-nox 2>/dev/null || true
systemctl enable qbittorrent-nox
systemctl start qbittorrent-nox

echo -e "${GREEN}✓ qBittorrent configured and started${NC}"

# Configure firewall if UFW is active
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "\n${YELLOW}Configuring firewall...${NC}"
    ufw allow ${JELLYFIN_PORT}/tcp
    ufw allow ${QBIT_PORT}/tcp
    ufw allow 6881:6889/tcp
    ufw allow 6881:6889/udp
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Service Information:${NC}"
echo -e "Media Directory: ${MEDIA_DIR}"
echo -e "Download Directory: ${QBIT_DOWNLOAD_DIR}"
echo -e "\n${YELLOW}Jellyfin:${NC}"
echo -e "  URL: http://${SERVER_IP}:${JELLYFIN_PORT}"
echo -e "  Complete setup through web interface"
echo -e "\n${YELLOW}qBittorrent:${NC}"
echo -e "  URL: http://${SERVER_IP}:${QBIT_PORT}"
echo -e "  Username: admin"
echo -e "  Password: adminadmin"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. Access Jellyfin and complete setup wizard"
echo -e "2. Add media libraries in Jellyfin:"
echo -e "   - Movies: ${MEDIA_DIR}/movies"
echo -e "   - TV Shows: ${MEDIA_DIR}/tv-shows"
echo -e "   - Music: ${MEDIA_DIR}/music"
echo -e "3. Access qBittorrent and change the default password"
echo -e "4. Downloaded files will appear in: ${QBIT_DOWNLOAD_DIR}"
echo -e "\n${YELLOW}Service Commands:${NC}"
echo -e "  systemctl status jellyfin"
echo -e "  systemctl status qbittorrent-nox"
echo -e "  systemctl restart jellyfin"
echo -e "  systemctl restart qbittorrent-nox"
echo -e "\n${GREEN}========================================${NC}"
