# ☁️ Nextcloud AppImage Auto-Updater

> Tired of manually downloading and replacing the Nextcloud Desktop AppImage on Linux? This tool hooks into your app launcher and automatically checks for new releases every time you open Nextcloud.

A lightweight Bash solution that:
- **Auto-discovers** the AppImage inside a dedicated folder (e.g. `~/App/Nextcloud/`) — no hardcoded filename needed
- Checks the installed version (from the filename pattern `Nextcloud-X.X.X-x86_64.AppImage`) against the **latest GitHub release** (`nextcloud-releases/desktop`)
- **Asks the user** before downloading anything
- Downloads the new `.AppImage`, replaces the old one **in-place**, keeps a `.bak` backup
- Falls back to launching the existing Nextcloud on any error
- Creates a `.desktop` launcher automatically if none is found
- Sends **desktop notifications** with the result

---

## 📋 Requirements

- Any Linux distro (no `dpkg` needed)
- `curl` (usually pre-installed)
- Nextcloud Desktop installed as `.AppImage` with version in the filename (e.g. `Nextcloud-33.0.2-x86_64.AppImage`)
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

During setup you will be asked for the **folder** where your AppImage lives. Default: `~/App/Nextcloud`.

The setup script will:
1. Ask for the folder containing your AppImage (e.g. `~/App/Nextcloud/`)
2. Auto-find the `Nextcloud*.AppImage` file inside that folder
3. Create `/usr/local/bin/nextcloud-update` with the folder path baked in
4. Make it executable
5. Find the system `.desktop` or create one from scratch
6. Patch the `Exec=` line to run the updater
7. Refresh the application launcher database

> You will be prompted for your `sudo` password once, to write to `/usr/local/bin/`.

---

## 📁 Folder Structure

```
~/App/Nextcloud/
├── Nextcloud-33.0.2-x86_64.AppImage       ← current version (launched)
└── Nextcloud-33.0.1-x86_64.AppImage.bak   ← previous version (backup)
```

After each update the old AppImage is kept as `.bak`. You can safely delete it once the new version is confirmed working.

---

## ⚙️ How it works

```
Click Nextcloud in app menu
        │
        ▼
 nextcloud-update runs
        │
        ├─ Scans ~/App/Nextcloud/ for Nextcloud*.AppImage
        ├─ Extracts installed version from filename
        ├─ Fetches latest version from GitHub API
        │
        ├─ Already up to date?   → notify ✅ → launch Nextcloud
        │
        ├─ New version found?    → ask user [Y/n]
        │       ├─ Y → download AppImage → replace in-place → notify 🎉 → launch
        │       └─ N → launch Nextcloud immediately
        │
        └─ Network/download error → notify ⚠️ → launch Nextcloud anyway
```

Version is read from the filename pattern `Nextcloud-X.X.X-x86_64.AppImage`.
Latest version is fetched from:
```
https://api.github.com/repos/nextcloud-releases/desktop/releases/latest
```

---

## 🖥️ Usage after setup

Run the updater manually at any time:

```bash
nextcloud-update
```

Override the folder temporarily:
```bash
NEXTCLOUD_APPIMAGE_DIR=/other/path/folder nextcloud-update
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
