#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  xoxo-media Teardown${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "\n${RED}WARNING: This will stop and remove all xoxo-media containers.${NC}"
echo -e "${YELLOW}Named volumes (config, database, certs) are preserved by default.${NC}"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Teardown cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}[1/2] Stopping and removing containers...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" down
echo -e "${GREEN}✓ Containers removed${NC}"

read -p "Also delete all volumes (config, databases, SSL certs)? THIS IS IRREVERSIBLE (yes/no): " REMOVE_VOLUMES

if [ "$REMOVE_VOLUMES" = "yes" ]; then
    echo -e "\n${YELLOW}[2/2] Removing volumes...${NC}"
    docker compose -f "${SCRIPT_DIR}/docker-compose.yml" down -v
    echo -e "${GREEN}✓ Volumes removed${NC}"
else
    echo -e "\n${YELLOW}[2/2] Volumes preserved.${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Teardown Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
