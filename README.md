# ☁️ Nextcloud AppImage Auto-Updater

> Tired of manually downloading and replacing the Nextcloud Desktop AppImage on Linux? This tool hooks into your app launcher and automatically checks for new releases every time you open Nextcloud.

A lightweight Bash solution that:
- Checks the installed AppImage version against the **latest GitHub release** (`nextcloud-releases/desktop`)
- **Asks the user** before downloading anything
- Downloads the new `.AppImage`, replaces the old one **in-place**, and keeps a `.bak` backup
- Falls back to launching the existing Nextcloud on any error (network, download, etc.)
- Creates a `.desktop` launcher automatically if none is found
- Sends **desktop notifications** with the result

---

## 📋 Requirements

- Any Linux distro (not Debian-specific — no `dpkg` needed)
- `curl` (usually pre-installed)
- Nextcloud Desktop installed as `.AppImage`
- `notify-send` for desktop notifications (optional — gracefully skipped if missing)

---

## 🚀 Installation

### One-liner

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Alexys829/nextcloud-appimage-autoupdater/main/setup.sh)
```

### Manual (clone the repo)

```bash
git clone https://github.com/Alexys829/nextcloud-appimage-autoupdater.git
cd nextcloud-appimage-autoupdater
chmod +x setup.sh
./setup.sh
```

During setup you will be asked for the path to your AppImage. Default: `~/App/Nextcloud-x86_64.AppImage`.

The setup script will:
1. Ask for the path of your existing Nextcloud AppImage
2. Create `/usr/local/bin/nextcloud-update` with the path baked in
3. Make it executable
4. Find the system `.desktop` or create one from scratch
5. Patch the `Exec=` line to run the updater
6. Refresh the application launcher database

> You will be prompted for your `sudo` password once, to write to `/usr/local/bin/`.

---

## ⚙️ How it works

```
Click Nextcloud in app menu
        │
        ▼
 nextcloud-update runs
        │
        ├─ Already up to date?   → notify ✅ → launch Nextcloud
        │
        ├─ New version found?    → ask user [Y/n]
        │       ├─ Y → download AppImage → replace in-place → notify 🎉 → launch
        │       └─ N → launch Nextcloud immediately
        │
        └─ Network/download error → notify ⚠️ → launch Nextcloud anyway
```

Version detection uses the filename pattern `Nextcloud-X.X.X-x86_64.AppImage`.
The latest version is fetched from the official GitHub Releases API:
```
https://api.github.com/repos/nextcloud-releases/desktop/releases/latest
```

---

## 🖥️ Usage after setup

You can also run the updater manually at any time:

```bash
nextcloud-update
```

Or override the AppImage path temporarily:
```bash
NEXTCLOUD_APPIMAGE=/other/path/Nextcloud.AppImage nextcloud-update
```

---

## 🔔 Desktop Notifications

| Event | Notification |
|---|---|
| Already up to date | `✅ Già aggiornato (X.X.X)` |
| Updated successfully | `🎉 Aggiornato a X.X.X!` |
| Network error | `⚠️ Impossibile verificare aggiornamenti` |
| Download failed | `❌ Download fallito` |

Notifications require `libnotify-bin`:
```bash
sudo apt install libnotify-bin
```

---

## 🗑️ Uninstall

```bash
sudo rm /usr/local/bin/nextcloud-update
rm ~/.local/share/applications/nextcloud.desktop
update-desktop-database ~/.local/share/applications/
```

---

## 📄 License

MIT — do whatever you want with it.
