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

# ── Chiedi percorso AppImage ───────────────────────────
DEFAULT_PATH="$HOME/App/Nextcloud-x86_64.AppImage"
read -r -p "$(echo -e "${YELLOW}➡️  Percorso AppImage Nextcloud [${DEFAULT_PATH}]: ")" USER_PATH
APPIMAGE_PATH="${USER_PATH:-$DEFAULT_PATH}"

# Espandi ~ manualmente se presente
APPIMAGE_PATH="${APPIMAGE_PATH/#\~/$HOME}"

if [ ! -f "$APPIMAGE_PATH" ]; then
    err "File non trovato: $APPIMAGE_PATH\n   Assicurati che il percorso sia corretto e riprova."
fi
ok "AppImage trovata: $APPIMAGE_PATH"

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

APPIMAGE_PATH="\${NEXTCLOUD_APPIMAGE:-${APPIMAGE_PATH}}"
GITHUB_API="https://api.github.com/repos/nextcloud-releases/desktop/releases/latest"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      Nextcloud Update Checker            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

log_info "Controllo versione Nextcloud installata..."
INSTALLED=""
if [ -f "\$APPIMAGE_PATH" ]; then
    INSTALLED=\$(basename "\$APPIMAGE_PATH" | grep -oP '\\d+\\.\\d+\\.\\d+' | head -1 || true)
    if [ -n "\$INSTALLED" ]; then
        log_info "Versione installata: \$INSTALLED"
    else
        INSTALLED=\$("\$APPIMAGE_PATH" --version 2>/dev/null | grep -oP '\\d+\\.\\d+\\.\\d+' | head -1 || true)
        [ -n "\$INSTALLED" ] && log_info "Versione installata: \$INSTALLED" || log_warning "Impossibile determinare la versione installata."
    fi
else
    log_warning "AppImage non trovata in: \$APPIMAGE_PATH"
fi

log_info "Controllo ultima versione disponibile su GitHub..."
API_RESPONSE=\$(curl -fsSL "\$GITHUB_API")
REMOTE_VERSION=\$(echo "\$API_RESPONSE" | grep '"tag_name"' | head -1 | grep -oP '"tag_name":\s*"\K[^"]+' )

if [ -z "\$REMOTE_VERSION" ]; then
    log_error "Impossibile recuperare l'ultima versione."
    notify-send "Nextcloud" "⚠️ Impossibile verificare aggiornamenti" --icon=nextcloud 2>/dev/null || true
    exec "\$APPIMAGE_PATH"
fi

log_info "Ultima versione disponibile: \$REMOTE_VERSION"
REMOTE_CLEAN="\${REMOTE_VERSION#v}"

if [ -n "\$INSTALLED" ] && [ "\$INSTALLED" = "\$REMOTE_CLEAN" ]; then
    log_info "Nextcloud è già aggiornato (\$INSTALLED). Avvio in corso..."
    notify-send "Nextcloud" "✅ Già aggiornato (\$INSTALLED)" --icon=nextcloud 2>/dev/null || true
    exec "\$APPIMAGE_PATH"
fi

echo ""
[ -n "\$INSTALLED" ] && log_warning "Nuova versione: \$REMOTE_CLEAN (installata: \$INSTALLED)" || log_warning "Nextcloud \$REMOTE_CLEAN disponibile."

read -r -p "\$(echo -e "\${BLUE}[?]\${NC} Vuoi aggiornare ora? [Y/n] ")" answer
[[ "\$answer" == "n" || "\$answer" == "N" ]] && { log_info "Rimandato. Avvio Nextcloud..."; exec "\$APPIMAGE_PATH"; }

log_info "Recupero link download AppImage..."
APPIMAGE_URL=\$(echo "\$API_RESPONSE" \
    | grep '"browser_download_url"' \
    | grep -i '\.AppImage' \
    | grep -i 'x86_64' \
    | grep -v '\.zsync' \
    | head -1 \
    | grep -oP '"browser_download_url":\s*"\K[^"]+' )

[ -z "\$APPIMAGE_URL" ] && APPIMAGE_URL="https://github.com/nextcloud-releases/desktop/releases/download/\${REMOTE_VERSION}/Nextcloud-\${REMOTE_CLEAN}-x86_64.AppImage"
log_info "URL: \$APPIMAGE_URL"

log_info "Download Nextcloud \$REMOTE_CLEAN in corso..."
TMP_DIR=\$(mktemp -d)
APPIMAGE_FILENAME="Nextcloud-\${REMOTE_CLEAN}-x86_64.AppImage"

if curl -L --progress-bar "\$APPIMAGE_URL" -o "\$TMP_DIR/\$APPIMAGE_FILENAME"; then
    log_info "Download completato."
else
    log_error "Download fallito. Avvio Nextcloud con la versione attuale..."
    rm -rf "\$TMP_DIR"
    notify-send "Nextcloud" "❌ Download fallito" --icon=nextcloud 2>/dev/null || true
    exec "\$APPIMAGE_PATH"
fi

log_info "Sostituzione AppImage..."
mkdir -p "\$(dirname "\$APPIMAGE_PATH")"
[ -f "\$APPIMAGE_PATH" ] && mv "\$APPIMAGE_PATH" "\${APPIMAGE_PATH}.bak" && log_info "Backup: \${APPIMAGE_PATH}.bak"
mv "\$TMP_DIR/\$APPIMAGE_FILENAME" "\$APPIMAGE_PATH"
chmod +x "\$APPIMAGE_PATH"
rm -rf "\$TMP_DIR"

log_info "Aggiornamento completato!"
notify-send "Nextcloud" "🎉 Aggiornato a \$REMOTE_CLEAN!" --icon=nextcloud 2>/dev/null || true

log_info "Avvio Nextcloud..."
exec "\$APPIMAGE_PATH"
SCRIPT

ok "Script nextcloud-update creato."

# ── 2. Rendi eseguibile ──────────────────────────────────
info "Impostazione permessi eseguibili..."
sudo chmod +x /usr/local/bin/nextcloud-update
ok "Permessi impostati."

# ── 3. Cerca il .desktop di Nextcloud ───────────────────
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
        info "Copio il .desktop da $DESKTOP_SYSTEM..."
        cp "$DESKTOP_SYSTEM" "$DESKTOP_LOCAL"
        ok "Copiato."
    else
        info "Nessun .desktop di sistema trovato. Creo un .desktop personalizzato..."
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
        ok ".desktop creato da zero."
    fi
else
    ok "File .desktop locale già presente."
fi

# ── 4. Modifica Exec= ─────────────────────────────────────────
info "Modifica riga Exec= nel .desktop..."
sed -i 's|^Exec=.*|Exec=bash -c "nextcloud-update"|' "$DESKTOP_LOCAL"
ok "Riga Exec= aggiornata."

# ── 5. Aggiorna database launcher ───────────────────────
info "Aggiornamento database applicazioni..."
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
ok "Database aggiornato."

# ── Fine ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Setup completato con successo! 🎉       ║"
echo "║                                          ║"
echo "║  Da ora, aprendo Nextcloud dal menu app  ║"
echo "║  verrà chiesto se aggiornare quando      ║"
echo "║  una nuova versione è disponibile.       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
