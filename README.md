# Media Server Stack

Automated setup for **Jellyfin + qBittorrent + FileBrowser** on Ubuntu VPS.

## Quick Install

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/yashan223/xoxo-media/master/install.sh | sudo bash

# SSL setup
curl -fsSL https://raw.githubusercontent.com/yashan223/xoxo-media/master/setup-nginx.sh | sudo bash

# Uninstall
curl -fsSL https://raw.githubusercontent.com/yashan223/xoxo-media/master/uninstall.sh | sudo bash
```

## Services

| Service | Port | Username | Password |
|---------|------|----------|----------|
| Jellyfin | 8096 | (setup wizard) | - |
| qBittorrent | 8080 | admin | adminadmin |
| FileBrowser | 8585 | admin | adminadmin12 |


## Directories

All services share a single `media` user/group for seamless file access.

```
/var/media/jellyfin/
├── downloads/   
├── movies/
├── tv-shows/
└── music/
```

## Commands

```bash
# Status
systemctl status jellyfin qbittorrent-nox filebrowser

# Restart
systemctl restart jellyfin
systemctl restart qbittorrent-nox
systemctl restart filebrowser

```
