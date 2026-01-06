# Media Server Stack

Automated setup for **Jellyfin + qBittorrent + FileBrowser** on Ubuntu VPS.

## Quick Start

```bash
# Install everything
sudo bash install.sh

# Setup SSL (optional)
sudo bash setup-nginx.sh

# Uninstall
sudo bash uninstall.sh
```

## Services

| Service | Port | Username | Password |
|---------|------|----------|----------|
| Jellyfin | 8096 | (setup wizard) | - |
| qBittorrent | 8080 | admin | adminadmin |
| FileBrowser | 8585 | admin | admin |

**Access:** `http://YOUR_SERVER_IP:PORT`

## Directories

```
/var/media/jellyfin/
├── downloads/    # qBittorrent downloads
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
