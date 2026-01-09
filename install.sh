#!/bin/bash

# Jellyfin, qBittorrent & FileBrowser Auto-Install Script for Ubuntu VPS
# This script installs Jellyfin, qBittorrent and FileBrowser with shared media directory

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
MEDIA_DIR="/var/media/jellyfin"
QBIT_DOWNLOAD_DIR="${MEDIA_DIR}/downloads"
MEDIA_USER="media"
MEDIA_GROUP="media"
QBIT_PORT=8080
JELLYFIN_PORT=8096
FILEBROWSER_PORT=8585

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jellyfin, qBittorrent & FileBrowser${NC}"
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
echo -e "\n${YELLOW}[1/8] Updating system packages...${NC}"
wait_for_apt
apt-get update
apt-get upgrade -y

# Install dependencies
wait_for_apt
echo -e "\n${YELLOW}[2/8] Installing dependencies...${NC}"
apt-get install -y curl gnupg software-properties-common apt-transport-https

# Install Jellyfin
echo -e "\n${YELLOW}[3/8] Installing Jellyfin...${NC}"

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
echo -e "\n${YELLOW}[4/8] Installing qBittorrent-nox...${NC}"
add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
apt-get update
apt-get install -y qbittorrent-nox

echo -e "${GREEN}✓ qBittorrent-nox installed successfully${NC}"

# Create media directories
echo -e "\n${YELLOW}[5/8] Creating media directories...${NC}"
mkdir -p "${MEDIA_DIR}"
mkdir -p "${QBIT_DOWNLOAD_DIR}"
mkdir -p "${MEDIA_DIR}/movies"
mkdir -p "${MEDIA_DIR}/tv-shows"
mkdir -p "${MEDIA_DIR}/music"

# Create shared media user and group for all services
echo -e "\n${YELLOW}[6/8] Configuring shared media user...${NC}"
if ! getent group "${MEDIA_GROUP}" &>/dev/null; then
    groupadd "${MEDIA_GROUP}"
    echo -e "${GREEN}✓ Group '${MEDIA_GROUP}' created${NC}"
fi

if ! id "${MEDIA_USER}" &>/dev/null; then
    useradd -r -m -d /home/${MEDIA_USER} -s /usr/sbin/nologin -g "${MEDIA_GROUP}" "${MEDIA_USER}"
    echo -e "${GREEN}✓ User '${MEDIA_USER}' created${NC}"
else
    echo -e "${YELLOW}User '${MEDIA_USER}' already exists${NC}"
fi

# Add jellyfin user to media group
usermod -a -G ${MEDIA_GROUP} jellyfin

# Set permissions - media user owns everything, group has full access
chown -R ${MEDIA_USER}:${MEDIA_GROUP} "${MEDIA_DIR}"
chmod -R 775 "${MEDIA_DIR}"

# Create qBittorrent config directory
QBIT_CONFIG_DIR="/home/${MEDIA_USER}/.config/qBittorrent"
mkdir -p "${QBIT_CONFIG_DIR}"

# Create qBittorrent systemd service
cat > /etc/systemd/system/qbittorrent-nox.service <<EOF
[Unit]
Description=qBittorrent-nox
After=network.target

[Service]
Type=simple
User=${MEDIA_USER}
Group=${MEDIA_GROUP}
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
Bittorrent\MaxRatio=0
Bittorrent\MaxRatioAction=1
Bittorrent\MaxSeedingMinutes=0
EOF

chown -R ${MEDIA_USER}:${MEDIA_GROUP} "${QBIT_CONFIG_DIR}"

# Enable and start services
echo -e "\n${YELLOW}[7/8] Starting qBittorrent...${NC}"
systemctl unmask qbittorrent-nox 2>/dev/null || true
systemctl enable qbittorrent-nox
systemctl start qbittorrent-nox

echo -e "${GREEN}✓ qBittorrent configured and started${NC}"

# Install FileBrowser
echo -e "\n${YELLOW}[8/8] Installing FileBrowser...${NC}"
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Create config directory
mkdir -p /var/lib/filebrowser

# Create FileBrowser database and config (remove old db to ensure fresh credentials)
rm -f /var/lib/filebrowser/filebrowser.db
filebrowser config init -d /var/lib/filebrowser/filebrowser.db
filebrowser config set -d /var/lib/filebrowser/filebrowser.db --address 0.0.0.0
filebrowser config set -d /var/lib/filebrowser/filebrowser.db --port ${FILEBROWSER_PORT}
filebrowser config set -d /var/lib/filebrowser/filebrowser.db --root ${QBIT_DOWNLOAD_DIR}
filebrowser users add admin adminadmin12 --perm.admin -d /var/lib/filebrowser/filebrowser.db

# Set permissions - FileBrowser config owned by media user
chown -R ${MEDIA_USER}:${MEDIA_GROUP} /var/lib/filebrowser

# Create FileBrowser systemd service
cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
Type=simple
User=${MEDIA_USER}
Group=${MEDIA_GROUP}
ExecStart=/usr/local/bin/filebrowser -d /var/lib/filebrowser/filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable filebrowser
systemctl start filebrowser

echo -e "${GREEN}✓ FileBrowser installed and started${NC}"

# Configure firewall if UFW is active
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "\n${YELLOW}Configuring firewall...${NC}"
    ufw allow ${JELLYFIN_PORT}/tcp
    ufw allow ${QBIT_PORT}/tcp
    ufw allow ${FILEBROWSER_PORT}/tcp
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
echo -e "\n${YELLOW}FileBrowser:${NC}"
echo -e "  URL: http://${SERVER_IP}:${FILEBROWSER_PORT}"
echo -e "  Username: admin"
echo -e "  Password: adminadmin12"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. Access Jellyfin and complete setup wizard"
echo -e "2. Add media libraries in Jellyfin:"
echo -e "   - Movies: ${MEDIA_DIR}/movies"
echo -e "   - TV Shows: ${MEDIA_DIR}/tv-shows"
echo -e "   - Music: ${MEDIA_DIR}/music"
echo -e "3. Change default passwords for qBittorrent and FileBrowser"
echo -e "4. Downloaded files will appear in: ${QBIT_DOWNLOAD_DIR}"
echo -e "\n${YELLOW}Service Commands:${NC}"
echo -e "  systemctl status jellyfin"
echo -e "  systemctl status qbittorrent-nox"
echo -e "  systemctl status filebrowser"
echo -e "\n${GREEN}========================================${NC}"
