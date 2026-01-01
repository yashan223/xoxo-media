# Jellyfin & qBittorrent Media Server

Automated installation scripts for setting up a complete media server with Jellyfin and qBittorrent on Ubuntu VPS.

## Features

- **Jellyfin** - Media server for streaming movies, TV shows, and music
- **qBittorrent** - Torrent client with web interface
- Shared media directory with proper permissions
- Systemd service management
- Automatic firewall configuration (if UFW enabled)

## Quick Start

### Installation

```bash
sudo bash install.sh
```

### Uninstallation

```bash
sudo bash uninstall.sh
```

## Default Configuration

### Ports
- **Jellyfin**: 8096
- **qBittorrent**: 8080

### Credentials
- **qBittorrent Web UI**
  - Username: `admin`
  - Password: `adminadmin`

### Directories
- Media Root: `/var/media/jellyfin`
- Downloads: `/var/media/jellyfin/downloads`
- Movies: `/var/media/jellyfin/movies`
- TV Shows: `/var/media/jellyfin/tv-shows`
- Music: `/var/media/jellyfin/music`

## Access Your Services

Replace `YOUR_SERVER_IP` with your VPS IP address:

- **Jellyfin**: `http://YOUR_SERVER_IP:8096`
- **qBittorrent**: `http://YOUR_SERVER_IP:8080`

## Post-Installation Steps

1. **Access Jellyfin** and complete the setup wizard
2. **Add media libraries** in Jellyfin:
   - Movies: `/var/media/jellyfin/movies`
   - TV Shows: `/var/media/jellyfin/tv-shows`
   - Music: `/var/media/jellyfin/music`
3. **Login to qBittorrent** and change the default password
4. Downloads will automatically save to `/var/media/jellyfin/downloads`

## Service Management

```bash
# Check service status
systemctl status jellyfin
systemctl status qbittorrent-nox

# Restart services
systemctl restart jellyfin
systemctl restart qbittorrent-nox

# View logs
journalctl -u jellyfin -f
journalctl -u qbittorrent-nox -f
```

## Requirements

- Ubuntu 20.04 or newer
- Root access (sudo)
- Internet connection

## Notes

- The uninstall script preserves media files by default (asks for confirmation)
- All services run as system users with appropriate permissions
- Jellyfin user is added to qbittorrent group for proper file access
