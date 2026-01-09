#!/bin/bash

# Media Server Uninstall Script for Ubuntu VPS
# Removes Jellyfin, qBittorrent, FileBrowser, and Nginx configurations

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
MEDIA_DIR="/var/media/jellyfin"
MEDIA_USER="media"
MEDIA_GROUP="media"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Media Server Uninstallation${NC}"
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
echo -e "  - FileBrowser (if installed)"
echo -e "  - Nginx reverse proxy configs (optional)"
echo -e "\n${YELLOW}NOTE: Media files in ${MEDIA_DIR} will be PRESERVED${NC}"
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
fi

# Stop services
echo -e "\n${YELLOW}[1/7] Stopping services...${NC}"
systemctl unmask qbittorrent-nox 2>/dev/null || true
systemctl unmask jellyfin 2>/dev/null || true
systemctl stop qbittorrent-nox 2>/dev/null || true
systemctl stop jellyfin 2>/dev/null || true
systemctl stop filebrowser 2>/dev/null || true
systemctl disable qbittorrent-nox 2>/dev/null || true
systemctl disable jellyfin 2>/dev/null || true
systemctl disable filebrowser 2>/dev/null || true

echo -e "${GREEN}✓ Services stopped${NC}"

# Remove qBittorrent
echo -e "\n${YELLOW}[2/7] Removing qBittorrent...${NC}"
apt-get remove --purge -y qbittorrent-nox 2>/dev/null || true
add-apt-repository -y --remove ppa:qbittorrent-team/qbittorrent-stable 2>/dev/null || true

echo -e "${GREEN}✓ qBittorrent removed${NC}"

# Remove Jellyfin
echo -e "\n${YELLOW}[3/7] Removing Jellyfin...${NC}"
apt-get remove --purge -y jellyfin 2>/dev/null || true
rm -f /etc/apt/sources.list.d/jellyfin.list
rm -f /etc/apt/trusted.gpg.d/jellyfin.gpg

echo -e "${GREEN}✓ Jellyfin removed${NC}"

# Remove FileBrowser
echo -e "\n${YELLOW}[4/7] Removing FileBrowser...${NC}"
if [ -f /usr/local/bin/filebrowser ]; then
    rm -f /usr/local/bin/filebrowser
    rm -rf /var/lib/filebrowser
    rm -rf /etc/filebrowser
    rm -f /etc/systemd/system/filebrowser.service
    echo -e "${GREEN}✓ FileBrowser removed${NC}"
else
    echo -e "${YELLOW}FileBrowser not found, skipping${NC}"
fi

# Remove systemd service file
echo -e "\n${YELLOW}[5/7] Removing systemd service files...${NC}"
rm -f /etc/systemd/system/qbittorrent-nox.service
systemctl daemon-reload

echo -e "${GREEN}✓ Service files removed${NC}"

# Remove media user
echo -e "\n${YELLOW}[6/7] Removing media user...${NC}"
if id "${MEDIA_USER}" &>/dev/null; then
    userdel -r "${MEDIA_USER}" 2>/dev/null || true
    echo -e "${GREEN}✓ User '${MEDIA_USER}' removed${NC}"
else
    echo -e "${YELLOW}User '${MEDIA_USER}' not found, skipping${NC}"
fi
if getent group "${MEDIA_GROUP}" &>/dev/null; then
    groupdel "${MEDIA_GROUP}" 2>/dev/null || true
    echo -e "${GREEN}✓ Group '${MEDIA_GROUP}' removed${NC}"
fi

# Clean up apt
echo -e "\n${YELLOW}[7/7] Cleaning up...${NC}"
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
    ufw delete allow 8585/tcp 2>/dev/null || true
    ufw delete allow 6881:6889/tcp 2>/dev/null || true
    ufw delete allow 6881:6889/udp 2>/dev/null || true
    echo -e "${GREEN}✓ Firewall rules removed${NC}"
fi

# Ask about Nginx removal
NGINX_REMOVED="no"
if [ -f /etc/nginx/sites-available/jellyfin ] || [ -f /etc/nginx/sites-available/qbittorrent ] || [ -f /etc/nginx/sites-available/filebrowser ]; then
    echo -e "\n${YELLOW}Nginx reverse proxy configuration detected.${NC}"
    read -p "Do you want to remove Nginx configs? (yes/no): " REMOVE_NGINX

    if [ "$REMOVE_NGINX" = "yes" ]; then
        echo -e "${YELLOW}Removing Nginx configurations...${NC}"
        rm -f /etc/nginx/sites-enabled/jellyfin
        rm -f /etc/nginx/sites-enabled/qbittorrent
        rm -f /etc/nginx/sites-enabled/filebrowser
        rm -f /etc/nginx/sites-available/jellyfin
        rm -f /etc/nginx/sites-available/qbittorrent
        rm -f /etc/nginx/sites-available/filebrowser
        
        # Reload nginx if it's running
        if systemctl is-active --quiet nginx; then
            systemctl reload nginx
        fi
        
        NGINX_REMOVED="yes"
        echo -e "${GREEN}✓ Nginx configs removed${NC}"
        
        # Ask about removing Nginx entirely
        read -p "Do you want to uninstall Nginx completely? (yes/no): " REMOVE_NGINX_PKG
        if [ "$REMOVE_NGINX_PKG" = "yes" ]; then
            systemctl stop nginx 2>/dev/null || true
            apt-get remove --purge -y nginx certbot python3-certbot-nginx 2>/dev/null || true
            echo -e "${GREEN}✓ Nginx uninstalled${NC}"
        fi
    fi
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Uninstallation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Summary:${NC}"
echo -e "  ✓ Jellyfin uninstalled"
echo -e "  ✓ qBittorrent-nox uninstalled"
echo -e "  ✓ FileBrowser uninstalled"
echo -e "  ✓ System services removed"
echo -e "  ✓ Users removed"
if [ "$NGINX_REMOVED" = "yes" ]; then
    echo -e "  ✓ Nginx configs removed"
fi

if [ "$REMOVE_MEDIA" = "yes" ]; then
    echo -e "  ✓ Media directory removed"
else
    echo -e "  ✓ Media directory preserved: ${MEDIA_DIR}"
fi

echo -e "\n${GREEN}========================================${NC}"
