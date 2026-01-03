# Jellyfin & qBittorrent Media Server

Automated setup for Jellyfin + qBittorrent on Ubuntu VPS.

## Installation

```bash
sudo bash install.sh
```

## Reverse Proxy + SSL (Optional)

```bash
sudo bash setup-nginx.sh
```

## Uninstall

```bash
sudo bash uninstall.sh
```

## Access

- **Jellyfin**: `http://YOUR_SERVER_IP:8096`
- **qBittorrent**: `http://YOUR_SERVER_IP:8080`
  - Username: `admin`
  - Password: `adminadmin`

## Directories

- Downloads: `/var/media/jellyfin/downloads`
- Movies: `/var/media/jellyfin/movies`
- TV Shows: `/var/media/jellyfin/tv-shows`
- Music: `/var/media/jellyfin/music`

## Service Commands

```bash
systemctl status jellyfin
systemctl status qbittorrent-nox
systemctl restart jellyfin
systemctl restart qbittorrent-nox
```
