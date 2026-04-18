#!/usr/bin/env bash
set -e

# ── Colori ──────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${YELLOW}➡️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Nextcloud AppImage Auto-Updater Setup   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Chiedi la cartella dove è salvata l'AppImage ────────────
DEFAULT_DIR="$HOME/App/Nextcloud"
read -r -p "$(echo -e "${YELLOW}➡️  Cartella AppImage Nextcloud [${DEFAULT_DIR}]: ")" USER_DIR
APPIMAGE_DIR="${USER_DIR:-$DEFAULT_DIR}"
APPIMAGE_DIR="${APPIMAGE_DIR/#\~/$HOME}"

mkdir -p "$APPIMAGE_DIR"

# Cerca il file AppImage nella cartella (ignora .bak)
APPIMAGE_PATH=$(find "$APPIMAGE_DIR" -maxdepth 1 -iname "Nextcloud*.AppImage" ! -name "*.bak" 2>/dev/null | sort -V | tail -1)

if [ -z "$APPIMAGE_PATH" ]; then
    err "Nessuna AppImage trovata in: $APPIMAGE_DIR\n   Metti il file Nextcloud-X.X.X-x86_64.AppImage nella cartella e riprova."
fi
ok "AppImage trovata: $(basename "$APPIMAGE_PATH")"

# ── 1. Crea lo script nextcloud-update ───────────────────
info "Creazione script /usr/local/bin/nextcloud-update..."

sudo tee /usr/local/bin/nextcloud-update > /dev/null << SCRIPT
#!/usr/bin/env bash
set -e
set -o pipefail

RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m'

log_info()    { echo -e "\${GREEN}[INFO]\${NC} \$1"; }
log_error()   { echo -e "\${RED}[ERROR]\${NC} \$1"; }
log_warning() { echo -e "\${YELLOW}[WARNING]\${NC} \$1"; }

# Cartella dedicata: sovrascrivibile via env
APPIMAGE_DIR="\${NEXTCLOUD_APPIMAGE_DIR:-${APPIMAGE_DIR}}"
GITHUB_API="https://api.github.com/repos/nextcloud-releases/desktop/releases/latest"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      Nextcloud Update Checker            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Ricerca AppImage nella cartella (ignora .bak) ──
log_info "Ricerca AppImage in: \$APPIMAGE_DIR"
APPIMAGE_PATH=""
if [ -d "\$APPIMAGE_DIR" ]; then
    APPIMAGE_PATH=\$(find "\$APPIMAGE_DIR" -maxdepth 1 -iname "Nextcloud*.AppImage" ! -name "*.bak" 2>/dev/null | sort -V | tail -1)
fi

if [ -n "\$APPIMAGE_PATH" ]; then
    log_info "AppImage trovata: \$(basename \"\$APPIMAGE_PATH\")"
else
    log_warning "Nessuna AppImage trovata in: \$APPIMAGE_DIR"
fi

# ── Versione installata (dal nome file) ────────────────
log_info "Controllo versione installata..."
INSTALLED=""
if [ -n "\$APPIMAGE_PATH" ]; then
    INSTALLED=\$(basename "\$APPIMAGE_PATH" | grep -oP '\\d+\\.\\d+\\.\\d+' | head -1 || true)
    [ -n "\$INSTALLED" ] && log_info "Versione installata: \$INSTALLED" || log_warning "Impossibile determinare versione dal nome file."
else
    log_warning "Nessuna AppImage, verrà scaricata l'ultima versione."
fi

# ── Ultima versione GitHub ──────────────────────────
log_info "Controllo ultima versione su GitHub..."
API_RESPONSE=\$(curl -fsSL "\$GITHUB_API")
REMOTE_VERSION=\$(echo "\$API_RESPONSE" | grep '"tag_name"' | head -1 | grep -oP '"tag_name":\s*"\K[^"]+')

if [ -z "\$REMOTE_VERSION" ]; then
    log_error "Impossibile recuperare l'ultima versione."
    notify-send "Nextcloud" "⚠️ Impossibile verificare aggiornamenti" --icon=nextcloud 2>/dev/null || true
    [ -n "\$APPIMAGE_PATH" ] && exec "\$APPIMAGE_PATH" || exit 1
fi

log_info "Ultima versione disponibile: \$REMOTE_VERSION"
REMOTE_CLEAN="\${REMOTE_VERSION#v}"

# ── Confronto versioni ────────────────────────────────
if [ -n "\$INSTALLED" ] && [ "\$INSTALLED" = "\$REMOTE_CLEAN" ]; then
    log_info "Nextcloud è già aggiornato (\$INSTALLED). Avvio..."
    notify-send "Nextcloud" "✅ Già aggiornato (\$INSTALLED)" --icon=nextcloud 2>/dev/null || true
    exec "\$APPIMAGE_PATH"
fi

echo ""
[ -n "\$INSTALLED" ] && log_warning "Nuova versione: \$REMOTE_CLEAN (installata: \$INSTALLED)" || log_warning "Nextcloud \$REMOTE_CLEAN disponibile."

read -r -p "\$(echo -e "\${BLUE}[?]\${NC} Vuoi aggiornare ora? [Y/n] ")" answer
[[ "\$answer" == "n" || "\$answer" == "N" ]] && {
    log_info "Rimandato. Avvio Nextcloud..."
    [ -n "\$APPIMAGE_PATH" ] && exec "\$APPIMAGE_PATH" || { log_error "Nessuna AppImage disponibile."; exit 1; }
}

# ── URL download ─────────────────────────────────────
log_info "Recupero link download..."
APPIMAGE_URL=\$(echo "\$API_RESPONSE" \
    | grep '"browser_download_url"' \
    | grep -i '\.AppImage' \
    | grep -i 'x86_64' \
    | grep -v '\.zsync' \
    | head -1 \
    | grep -oP '"browser_download_url":\s*"\K[^"]+')

[ -z "\$APPIMAGE_URL" ] && APPIMAGE_URL="https://github.com/nextcloud-releases/desktop/releases/download/\${REMOTE_VERSION}/Nextcloud-\${REMOTE_CLEAN}-x86_64.AppImage"
log_info "URL: \$APPIMAGE_URL"

# ── Download ───────────────────────────────────────────
APPIMAGE_FILENAME="Nextcloud-\${REMOTE_CLEAN}-x86_64.AppImage"
log_info "Download \$APPIMAGE_FILENAME..."
TMP_DIR=\$(mktemp -d)

if curl -L --progress-bar "\$APPIMAGE_URL" -o "\$TMP_DIR/\$APPIMAGE_FILENAME"; then
    log_info "Download completato."
else
    log_error "Download fallito."
    rm -rf "\$TMP_DIR"
    notify-send "Nextcloud" "❌ Download fallito" --icon=nextcloud 2>/dev/null || true
    [ -n "\$APPIMAGE_PATH" ] && exec "\$APPIMAGE_PATH" || exit 1
fi

# ── Sostituzione in-place ──────────────────────────────
log_info "Installazione in \$APPIMAGE_DIR..."
mkdir -p "\$APPIMAGE_DIR"
[ -n "\$APPIMAGE_PATH" ] && [ -f "\$APPIMAGE_PATH" ] && mv "\$APPIMAGE_PATH" "\${APPIMAGE_PATH}.bak" && log_info "Backup: \$(basename \"\${APPIMAGE_PATH}.bak\")"

NEW_APPIMAGE_PATH="\$APPIMAGE_DIR/\$APPIMAGE_FILENAME"
mv "\$TMP_DIR/\$APPIMAGE_FILENAME" "\$NEW_APPIMAGE_PATH"
chmod +x "\$NEW_APPIMAGE_PATH"
rm -rf "\$TMP_DIR"

log_info "Aggiornamento completato!"
notify-send "Nextcloud" "🎉 Aggiornato a \$REMOTE_CLEAN!" --icon=nextcloud 2>/dev/null || true

log_info "Avvio Nextcloud \$REMOTE_CLEAN..."
exec "\$NEW_APPIMAGE_PATH"
SCRIPT

ok "Script nextcloud-update creato."

# ── 2. Rendi eseguibile ──────────────────────────────────
sudo chmod +x /usr/local/bin/nextcloud-update
ok "Permessi impostati."

# ── 3. Gestione file .desktop ──────────────────────────
DESKTOP_LOCAL="$HOME/.local/share/applications/nextcloud.desktop"
DESKTOP_SYSTEM=""

for candidate in \
    /usr/share/applications/nextcloud.desktop \
    /usr/share/applications/com.nextcloud.desktopclient.nextcloud.desktop \
    "$HOME/.local/share/applications/appimagekit-nextcloud-desktop.desktop"; do
    if [ -f "$candidate" ]; then
        DESKTOP_SYSTEM="$candidate"
        break
    fi
done

if [ ! -f "$DESKTOP_LOCAL" ]; then
    if [ -n "$DESKTOP_SYSTEM" ]; then
        info "Copio .desktop da $DESKTOP_SYSTEM..."
        cp "$DESKTOP_SYSTEM" "$DESKTOP_LOCAL"
        ok "Copiato."
    else
        info "Nessun .desktop trovato. Ne creo uno da zero..."
        cat > "$DESKTOP_LOCAL" << DESKFILE
[Desktop Entry]
Name=Nextcloud
Comment=Nextcloud Desktop Sync Client
Exec=bash -c "nextcloud-update"
Icon=nextcloud
Terminal=false
Type=Application
Categories=Network;FileTransfer;
StartupNotify=false
DESKFILE
        ok ".desktop creato."
    fi
else
    ok "File .desktop locale già presente."
fi

# ── 4. Patch Exec= ───────────────────────────────────────────
info "Aggiorno Exec= nel .desktop..."
sed -i 's|^Exec=.*|Exec=bash -c "nextcloud-update"|' "$DESKTOP_LOCAL"
ok "Exec= aggiornato."

# ── 5. Refresh launcher ──────────────────────────────────
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
ok "Database launcher aggiornato."

# ── Fine ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Setup completato con successo! 🎉       ║"
echo "║                                          ║"
echo "║  Cartella AppImage: ${APPIMAGE_DIR}  ║"
echo "║  Da ora aprendo Nextcloud dal menu       ║"
echo "║  controllerà aggiornamenti in automatico ║"
echo "╚══════════════════════════════════════════╝"
echo ""
