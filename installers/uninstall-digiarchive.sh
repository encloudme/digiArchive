#!/usr/bin/env bash
# ==============================================================================
# digiArchive v5.0.1 - Automated Linux Uninstallation Script
# ==============================================================================
set -e

# ANSI styling for terminal outputs
RED='\033[0;91m'
NC='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
YELLOW='\033[1;93m'

# Application installation metadata
APP_NAME="digiArchive"
ICON_NAME="${APP_NAME}.png"
APP_VERSION="v5.0.1"
TARGET_BIN="/usr/local/bin/$APP_NAME"

# Updated to target system-wide desktop entry location
SYS_APP_DIR="/usr/share/applications"
DESKTOP_FILE="$SYS_APP_DIR/digital-archive.desktop"

# Updated to target system-wide icon and pixmap locations
SYS_ICON_DIR="/usr/share/icons"
SYS_HICOLOR_DIR="$SYS_ICON_DIR/hicolor"
SYS_PIXMAPS_DIR="/usr/share/pixmaps"
HICOLOR_SIZES=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "512x512")

# Retained user-local configuration and vault directories
CONFIG_DIR="$HOME/.config/digital-archive"
VAULT_DIR="$HOME/digiArchive_Vault"

# Guardrail: Prevent running entire uninstaller as root to preserve user paths
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ [Error] Do NOT run this uninstaller directly with 'sudo' or as root.${NC}"
    echo -e "   Running as root prevents resolving your correct user home directory ($HOME)."
    echo -e "   💡 ${BOLD}Please run as your regular user:${NC} ./${0##*/}"
    echo -e "   The script will request sudo authorization when deleting files from /usr/."
    exit 1
fi

echo -e "${BLUE}${BOLD}======================================================================${NC}"
echo -e "${BLUE}${BOLD}          🏛️  Uninstalling ${APP_NAME} (${APP_VERSION})                   ${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}"

read -r -p "$(echo -e " 🗑️  ${YELLOW}${BOLD}Are you sure you want to uninstall ${APP_NAME}? (y/N): ${NC}")" choice
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    echo -e " 🛑 ${RED}${BOLD}[Cancel] Uninstallation aborted by user.${NC}"
    exit 0
fi

# Validated administrative privileges upfront before modifying system directories
echo -e "\n🔐 ${BOLD}Validating administrative (sudo) privileges...${NC}"
if ! sudo -v; then
    echo -e "${RED}❌ [Error] Sudo authentication failed. System files cannot be removed.${NC}"
    exit 1
fi
echo -e "   -> ${GREEN}✔ Sudo access verified.${NC}\n"

# Removed binary executable from /usr/local/bin using elevated permissions
echo -e "🗑️  ${BOLD}Step 1: Removing executable binary...${NC}"
if [ -f "$TARGET_BIN" ]; then
    sudo rm -f "$TARGET_BIN"
    echo -e "   -> ${GREEN}✔ Removed binary: $TARGET_BIN${NC}"
else
    echo -e "   -> ℹ Binary not found at $TARGET_BIN (Skipped)."
fi

# Removed system-wide desktop launcher entry
echo -e "🗑️  ${BOLD}Step 2: Removing desktop launcher...${NC}"
if [ -f "$DESKTOP_FILE" ]; then
    sudo rm -f "$DESKTOP_FILE"
    echo -e "   -> ${GREEN}✔ Removed system launcher: $DESKTOP_FILE${NC}"
fi

# Cleaned legacy user-local desktop launcher if previously present
if [ -f "$HOME/.local/share/applications/digital-archive.desktop" ]; then
    rm -f "$HOME/.local/share/applications/digital-archive.desktop"
    echo -e "   -> ${GREEN}✔ Cleaned legacy user launcher in ~/.local/share/applications/${NC}"
fi

# Removed system-wide icons across all hicolor resolution trees and pixmaps
echo -e "🗑️  ${BOLD}Step 3: Removing system icons...${NC}"
if [ -f "$SYS_PIXMAPS_DIR/$ICON_NAME" ]; then
    sudo rm -f "$SYS_PIXMAPS_DIR/$ICON_NAME"
fi

for size in "${HICOLOR_SIZES[@]}"; do
    target_icon="$SYS_HICOLOR_DIR/$size/apps/$ICON_NAME"
    if [ -f "$target_icon" ]; then
        sudo rm -f "$target_icon"
    fi
done
echo -e "   -> ${GREEN}✔ Removed icons from $SYS_HICOLOR_DIR and $SYS_PIXMAPS_DIR${NC}"

# Cleaned legacy user-local icons if previously present
rm -f "$HOME/.local/share/icons/$ICON_NAME"
for size in "${HICOLOR_SIZES[@]}"; do
    rm -f "$HOME/.local/share/icons/hicolor/$size/apps/$ICON_NAME" 2>/dev/null || true
done

# Refreshed system desktop database and GTK icon caches
echo -e "🔄 ${BOLD}Step 4: Refreshing system caches...${NC}"
if command -v update-desktop-database &> /dev/null; then
    sudo update-desktop-database "$SYS_APP_DIR" || true
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache &> /dev/null; then
    sudo gtk-update-icon-cache -f -t "$SYS_HICOLOR_DIR" 2>/dev/null || true
fi
echo -e "   -> ${GREEN}✔ System desktop and icon registries refreshed.${NC}"

# Prompted user for optional removal of user-local configuration directory
echo ""
read -rp "$(echo -e "❓ ${BOLD}Do you want to remove user settings (~/.config/digital-archive)? [y/N]: ${NC}")" REMOVE_CONFIG
if [[ "$REMOVE_CONFIG" =~ ^[Yy]$ ]]; then
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        echo -e "   -> ${GREEN}✔ Removed configuration directory: $CONFIG_DIR${NC}"
    fi
fi

# Preserved master archive vault data with clear retention notification
echo ""
echo -e "${YELLOW}⚠️  NOTE: Your master repository vault at '$VAULT_DIR' has been PRESERVED.${NC}"
echo "   If you wish to permanently delete your vault and catalog database, run:"
echo "   $ rm -rf \"$VAULT_DIR\""
echo "   CAUTION: Removing vault folder, will wipe off the entire archive generated and the metadata."
echo ""
echo -e "${GREEN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}✅ Uninstallation Complete.${NC}"
echo -e "${GREEN}${BOLD}======================================================================${NC}"