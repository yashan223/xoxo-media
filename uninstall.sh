#!/bin/bash

# Jellyfin & qBittorrent Uninstall Script for Ubuntu VPS
# This script removes Jellyfin and qBittorrent installations

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
MEDIA_DIR="/var/media/jellyfin"
QBIT_USER="qbittorrent"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jellyfin & qBittorrent Uninstallation${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Ask for confirmation
echo -e "\n${RED}WARNING: This will remove:${NC}"
echo -e "  - Jellyfin server and configuration"
echo -e "  - qBittorrent-nox and configuration"
echo -e "  - qBittorrent user account"
echo -e "\n${YELLOW}NOTE: Media files in ${MEDIA_DIR} will be PRESERVED${NC}"
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
fi

# Stop services
echo -e "\n${YELLOW}[1/6] Stopping services...${NC}"
systemctl unmask qbittorrent-nox 2>/dev/null || true
systemctl unmask jellyfin 2>/dev/null || true
systemctl stop qbittorrent-nox 2>/dev/null || true
systemctl stop jellyfin 2>/dev/null || true
systemctl disable qbittorrent-nox 2>/dev/null || true
systemctl disable jellyfin 2>/dev/null || true

echo -e "${GREEN}✓ Services stopped${NC}"

# Remove qBittorrent
echo -e "\n${YELLOW}[2/6] Removing qBittorrent...${NC}"
apt-get remove --purge -y qbittorrent-nox 2>/dev/null || true
add-apt-repository -y --remove ppa:qbittorrent-team/qbittorrent-stable 2>/dev/null || true

echo -e "${GREEN}✓ qBittorrent removed${NC}"

# Remove Jellyfin
echo -e "\n${YELLOW}[3/6] Removing Jellyfin...${NC}"
apt-get remove --purge -y jellyfin 2>/dev/null || true
rm -f /etc/apt/sources.list.d/jellyfin.list
rm -f /etc/apt/trusted.gpg.d/jellyfin.gpg

echo -e "${GREEN}✓ Jellyfin removed${NC}"

# Remove systemd service file
echo -e "\n${YELLOW}[4/6] Removing systemd service files...${NC}"
rm -f /etc/systemd/system/qbittorrent-nox.service
systemctl daemon-reload

echo -e "${GREEN}✓ Service files removed${NC}"

# Remove qBittorrent user
echo -e "\n${YELLOW}[5/6] Removing qBittorrent user...${NC}"
if id "${QBIT_USER}" &>/dev/null; then
    userdel -r "${QBIT_USER}" 2>/dev/null || true
    echo -e "${GREEN}✓ User '${QBIT_USER}' removed${NC}"
else
    echo -e "${YELLOW}User '${QBIT_USER}' not found, skipping${NC}"
fi

# Clean up apt
echo -e "\n${YELLOW}[6/6] Cleaning up...${NC}"
apt-get autoremove -y
apt-get autoclean

echo -e "${GREEN}✓ Cleanup complete${NC}"

# Ask about media directory
echo -e "\n${YELLOW}Media Directory: ${MEDIA_DIR}${NC}"
read -p "Do you want to remove the media directory and all files? (yes/no): " REMOVE_MEDIA

if [ "$REMOVE_MEDIA" = "yes" ]; then
    echo -e "${RED}Removing media directory...${NC}"
    rm -rf "${MEDIA_DIR}"
    echo -e "${GREEN}✓ Media directory removed${NC}"
else
    echo -e "${YELLOW}Media directory preserved at: ${MEDIA_DIR}${NC}"
fi

# Remove firewall rules if UFW is active
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "\n${YELLOW}Removing firewall rules...${NC}"
    ufw delete allow 8096/tcp 2>/dev/null || true
    ufw delete allow 8080/tcp 2>/dev/null || true
    ufw delete allow 6881:6889/tcp 2>/dev/null || true
    ufw delete allow 6881:6889/udp 2>/dev/null || true
    echo -e "${GREEN}✓ Firewall rules removed${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Uninstallation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Summary:${NC}"
echo -e "  ✓ Jellyfin uninstalled"
echo -e "  ✓ qBittorrent-nox uninstalled"
echo -e "  ✓ System services removed"
echo -e "  ✓ User '${QBIT_USER}' removed"

if [ "$REMOVE_MEDIA" = "yes" ]; then
    echo -e "  ✓ Media directory removed"
else
    echo -e "  ✓ Media directory preserved: ${MEDIA_DIR}"
fi

echo -e "\n${GREEN}========================================${NC}"
