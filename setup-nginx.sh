#!/bin/bash

# Nginx Reverse Proxy + SSL Setup for Jellyfin & qBittorrent
# This script sets up nginx reverse proxy with Let's Encrypt SSL

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ports (must match install.sh)
JELLYFIN_PORT=8096
QBIT_PORT=8080

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Nginx Reverse Proxy + SSL Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Get domain inputs from user
echo -e "\n${YELLOW}Enter your domain names:${NC}"
read -p "Jellyfin domain (e.g., jellyfin.example.com): " JELLYFIN_DOMAIN
read -p "qBittorrent domain (e.g., qbit.example.com): " QBIT_DOMAIN
read -p "Email for SSL certificates: " SSL_EMAIL

# Validate inputs
if [ -z "$JELLYFIN_DOMAIN" ] || [ -z "$QBIT_DOMAIN" ] || [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}All fields are required!${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Configuration:${NC}"
echo -e "  Jellyfin: https://${JELLYFIN_DOMAIN}"
echo -e "  qBittorrent: https://${QBIT_DOMAIN}"
echo -e "  SSL Email: ${SSL_EMAIL}"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Install nginx and certbot
echo -e "\n${YELLOW}[1/4] Installing Nginx and Certbot...${NC}"
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

echo -e "${GREEN}✓ Nginx and Certbot installed${NC}"

# Create Jellyfin nginx config
echo -e "\n${YELLOW}[2/4] Configuring Nginx for Jellyfin...${NC}"
cat > /etc/nginx/sites-available/jellyfin <<EOF
server {
    listen 80;
    server_name ${JELLYFIN_DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${JELLYFIN_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Protocol \$scheme;
        proxy_set_header X-Forwarded-Host \$http_host;

        # Websocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Buffering
        proxy_buffering off;
    }
}
EOF

# Create qBittorrent nginx config
echo -e "\n${YELLOW}[3/4] Configuring Nginx for qBittorrent...${NC}"
cat > /etc/nginx/sites-available/qbittorrent <<EOF
server {
    listen 80;
    server_name ${QBIT_DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${QBIT_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Required for qBittorrent
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_cookie_path / "/; Secure";
    }
}
EOF

# Enable sites
ln -sf /etc/nginx/sites-available/jellyfin /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/qbittorrent /etc/nginx/sites-enabled/

# Test nginx config
nginx -t

# Reload nginx
systemctl reload nginx

echo -e "${GREEN}✓ Nginx configured${NC}"

# Setup SSL with Certbot
echo -e "\n${YELLOW}[4/4] Setting up SSL certificates...${NC}"
certbot --nginx -d ${JELLYFIN_DOMAIN} -d ${QBIT_DOMAIN} --non-interactive --agree-tos -m ${SSL_EMAIL}

# Enable auto-renewal
systemctl enable certbot.timer
systemctl start certbot.timer

echo -e "${GREEN}✓ SSL certificates installed${NC}"

# Configure firewall
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "\n${YELLOW}Configuring firewall...${NC}"
    ufw allow 'Nginx Full'
    echo -e "${GREEN}✓ Firewall configured${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Your services are now available at:${NC}"
echo -e "  Jellyfin: https://${JELLYFIN_DOMAIN}"
echo -e "  qBittorrent: https://${QBIT_DOMAIN}"
echo -e "\n${YELLOW}SSL certificates will auto-renew.${NC}"
echo -e "\n${YELLOW}Nginx Commands:${NC}"
echo -e "  systemctl status nginx"
echo -e "  systemctl restart nginx"
echo -e "  nginx -t  (test config)"
echo -e "\n${GREEN}========================================${NC}"
