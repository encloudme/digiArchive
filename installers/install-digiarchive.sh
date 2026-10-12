#!/usr/bin/env bash
# ==============================================================================
# digiArchive v5.0 - Automated Linux Installation Script
# ==============================================================================
set -e

# ANSI styling for terminal outputs
RED='\033[0;91m'
NC='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
YELLOW='\033[1;93m'
CYAN='\033[0;96m'

# App installation default paths
APP_NAME="digiArchive"
ICON_NAME="${APP_NAME}.png"
APP_VERSION="v5.0.0"
BIN_NAME="${APP_NAME}-linux-x86_64.bin"
TARGET_BIN="/usr/local/bin/$APP_NAME"

# Moved desktop launcher directory to system-wide location (requires sudo)
SYS_APP_DIR="/usr/share/applications"
DESKTOP_FILE="$SYS_APP_DIR/digital-archive.desktop"

# Retained user-local configuration path to preserve private user data
CONFIG_DIR="$HOME/.config/digital-archive"

# Switched icon directories to system-wide FreeDesktop standards (requires sudo)
SYS_ICON_DIR="/usr/share/icons"
SYS_HICOLOR_DIR="$SYS_ICON_DIR/hicolor"
SYS_PIXMAPS_DIR="/usr/share/pixmaps"

# GNOME standard icon sizes
HICOLOR_SIZES=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "512x512")

# Helper function to compute SHA-256 hash safely
get_file_sha256() {
    if [ ! -f "$1" ]; then
        echo "MISSING"
        return
    fi
    if command -v sha256sum &>/dev/null; then
        sha256sum "$1" 2>/dev/null | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "UNKNOWN"
    fi
}

# Detect package manager once at script start
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

PKG_MGR=$(detect_package_manager)

# Helper function to print a tailored install hint
show_install_hint() {
    local tool_name="$1"
    local deb_pkg="$2"
    local fed_pkg="$3"
    local arch_pkg="$4"

    echo -e "  💡 ${BOLD}Run this command to install ${tool_name}:${NC}"
    case "$PKG_MGR" in
        apt)
            echo -e "     ${BOLD}sudo apt update && sudo apt install ${deb_pkg}${NC}"
            ;;
        dnf)
            echo -e "     ${BOLD}sudo dnf install ${fed_pkg}${NC}"
            ;;
        pacman)
            echo -e "     ${BOLD}sudo pacman -S ${arch_pkg}${NC}"
            ;;
        *)
            echo -e "     - Debian/Ubuntu:  sudo apt install ${deb_pkg}"
            echo -e "     - Fedora/RHEL:    sudo dnf install ${fed_pkg}"
            echo -e "     - Arch Linux:     sudo pacman -S ${arch_pkg}"
            ;;
    esac
    echo ""
}

DESKTOP_UPDATED=false
ICON_UPDATED=false

log_separator() { echo -e "${BLUE}${BOLD}======================================================================${NC}"; }
log_end_process() { echo -e "${GREEN}${BOLD}======================================================================${NC}"; }
log_user_aborted() { echo -e " 🛑 ${RED}${BOLD}[Cancel] Installation aborted by user.${NC}" ; }

log_separator
# Fixed command syntax error by removing the accidental leading dash
echo -e "${BLUE}${BOLD}         🏛️  ${APP_NAME} ${APP_VERSION} (Linux x86_64) Installation        *${NC}"
log_separator

# =====================================================================================================================
# Guardrail: Prevent running the whole script as root / sudo
# =====================================================================================================================
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ [Error] Do NOT run this installer directly with 'sudo' or as the root user.${NC}"
    echo -e "   Running as root causes user configuration files to be created with root-only permissions."
    echo -e "   💡 ${BOLD}Please run as your regular user:${NC} ./${0##*/}"
    echo -e "   The script will prompt for sudo access automatically when writing to /usr/local/bin and /usr/share/."
    exit 1
fi

read -r -p "$(echo -e " 📥 ${GREEN}${BOLD}Install ${APP_NAME} (${APP_VERSION})? (y/N): ${NC}")" choice
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    log_user_aborted
    log_end_process
    exit 0
fi

# =====================================================================================================================
# Validate sudo credentials upfront
# =====================================================================================================================
echo -e "\n🔐 ${BOLD}Validating administrative (sudo) privileges...${NC}"
echo -e "   (Needed for copying the binary to /usr/local/bin and icons to /usr/share/)"

if ! sudo -v; then
    echo -e "\n${RED}❌ [Error] Sudo authentication failed.${NC}"
    echo -e "   Possible causes:"
    echo -e "   1. Incorrect password entered."
    echo -e "   2. User '${USER}' is not in the system's administrative group."
    echo -e "      💡 To grant sudo access (from an existing admin account):"
    echo -e "         - Debian/Ubuntu: ${BOLD}sudo usermod -aG sudo $USER${NC}"
    echo -e "         - Fedora/RHEL:   ${BOLD}sudo usermod -aG wheel $USER${NC}"
    echo -e "         - Arch Linux:    ${BOLD}sudo usermod -aG wheel $USER${NC}"
    echo -e "   3. Remember: Always run this installer as ${BOLD}./${0##*/}${NC} (do NOT use ${BOLD}sudo ./${0##*/}${NC}).\n"
    log_end_process
    exit 1
fi
echo -e "   -> ${GREEN}✔ Sudo access verified.${NC}\n"

# =====================================================================================================================
# 1. Resolve project root directory relative to this script
# =====================================================================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_PATH="$REPO_ROOT/releases"

# =====================================================================================================================
# 2. Pre-flight dependency audit
# =====================================================================================================================
echo -e "${BOLD}🔍 Pre-flight dependency audit...${NC}"

# 1. Check Python3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED} ❌ [Error] Python3 is not installed on your system.${NC}"
    echo -e "${RED}    Please install Python3 before running this installer.${NC}\n"
    log_end_process
    exit 1
fi

# 2. Check ADB
if ! command -v adb &> /dev/null; then
    echo -e " ⚠ ${YELLOW}[Warning] 'adb' was not detected on your system.${NC}"
    show_install_hint "adb" "adb android-tools-adb" "android-tools" "android-tools"
fi

# 3. Check SQLite3
if ! command -v sqlite3 &> /dev/null; then
    echo -e " ⚠ ${YELLOW}[Warning] 'sqlite3' CLI utility was not detected.${NC}"
    show_install_hint "sqlite3" "sqlite3" "sqlite" "sqlite"
fi

# 4. Check for PyQt6 & Python Runtime (Source execution & Dev tools)
echo -e "\n${BLUE}🔍 Verifying Python runtime and GUI libraries (PyQt6)...${NC}"
if command -v python3 &> /dev/null; then
    if ! python3 -c "import PyQt6" &> /dev/null; then
        echo -e " ⚠ ${YELLOW}[Notice] PyQt6 is not installed in the system Python environment.${NC}"
        echo -e "    ${CYAN}Note:${NC} The standalone binary bundles PyQt6, but running source tools, CLI utilities, or tests requires it."

        REQ_FILE=""
        if [ -f "$REPO_ROOT/requirements.txt" ]; then
            REQ_FILE="$REPO_ROOT/requirements.txt"
        elif [ -f "$SCRIPT_DIR/requirements.txt" ]; then
            REQ_FILE="$SCRIPT_DIR/requirements.txt"
        fi

        if [ -n "$REQ_FILE" ]; then
            read -r -p "$(echo -e "${BLUE} ❔ Would you like to install required packages from requirements.txt now? (y/N): ${NC}")" req_choice
            if [[ "$req_choice" =~ ^[Yy]$ ]]; then
                echo -e "📦 Installing packages from $REQ_FILE..."
                python3 -m pip install -r "$REQ_FILE" || pip3 install -r "$REQ_FILE" || true
            fi
        else
            echo -e "  💡 To install PyQt6 manually: ${BOLD}pip install PyQt6${NC}\n"
        fi
    else
        echo -e " ✅ ${GREEN}GUI Framework:${NC} PyQt6 detected in Python environment."
    fi
fi

# =====================================================================================================================
# 3. Install binary executable (Local resolution with Multi-Format Release Fallback)
# =====================================================================================================================
log_separator
echo -e "📦 ${GREEN}${BOLD}Locating application binary...${NC}"

# Base release URL template
RELEASE_BASE_URL="https://github.com/encloudme/digiArchive/releases/download/${APP_VERSION}"

DEFAULT_DOWNLOAD_FILE="$HOME/Downloads/$BIN_NAME"
TARGET_RELEASE_FILE="$BIN_PATH/$BIN_NAME"
BIN_STEM="${BIN_NAME%.bin}"

# Check local candidate paths first (file exists and size > 0)
BIN_FILE=""
if [ -f "$BIN_PATH/$BIN_NAME" ] && [ -s "$BIN_PATH/$BIN_NAME" ]; then
    BIN_FILE="$BIN_PATH/$BIN_NAME"
elif [ -f "$SCRIPT_DIR/$BIN_NAME" ] && [ -s "$SCRIPT_DIR/$BIN_NAME" ]; then
    BIN_FILE="$SCRIPT_DIR/$BIN_NAME"
elif [ -f "$REPO_ROOT/$BIN_NAME" ] && [ -s "$REPO_ROOT/$BIN_NAME" ]; then
    BIN_FILE="$REPO_ROOT/$BIN_NAME"
fi

# Fallback: Binary not found locally - check GitHub for .bin, .tar.gz, or .zip
if [ -z "$BIN_FILE" ]; then
    echo -e " ⚠ ${YELLOW}[Notice] Standalone binary '${BIN_NAME}' was not found locally.${NC}"
    mkdir -p "$BIN_PATH"

    read -r -p "$(echo -e " 🌐 ${BLUE}${BOLD}Would you like to auto-download from GitHub releases? (y/N): ${NC}")" dl_choice

    if [[ "$dl_choice" =~ ^[Yy]$ ]]; then
        # Priority order of release assets to check and download
        CANDIDATE_ASSETS=(
            "${BIN_NAME}"
            "${BIN_STEM}.tar.gz"
            "${BIN_STEM}.zip"
            "${APP_NAME}-linux-x86_64.tar.gz"
            "${APP_NAME}-linux-x86_64.zip"
        )

        DOWNLOADED_PAYLOAD=""
        MATCHED_ASSET=""

        for asset in "${CANDIDATE_ASSETS[@]}"; do
            candidate_url="${RELEASE_BASE_URL}/${asset}"
            echo -e " 🔍 Checking asset: ${BLUE}${asset}${NC}..."

            TEMP_DOWNLOAD=$(mktemp)
            DOWNLOAD_STATUS=false

            # Use -f to fail on 404, -L to follow GitHub CDN 302 redirects
        if command -v curl &> /dev/null; then
                if curl -fL --silent --show-error "$candidate_url" -o "$TEMP_DOWNLOAD" 2>/dev/null; then
                    DOWNLOAD_STATUS=true
                fi
        elif command -v wget &> /dev/null; then
                if wget -q -O "$TEMP_DOWNLOAD" "$candidate_url" 2>/dev/null; then
                    DOWNLOAD_STATUS=true
                fi
            fi

            # Validate that download succeeded and returned a non-empty payload
            if [ "$DOWNLOAD_STATUS" = true ] && [ -s "$TEMP_DOWNLOAD" ]; then
                echo -e "   -> ${GREEN}✔ Found and downloaded: ${asset}${NC}"
                DOWNLOADED_PAYLOAD="$TEMP_DOWNLOAD"
                MATCHED_ASSET="$asset"
                break
        else
                rm -f "$TEMP_DOWNLOAD"
            fi
        done

        # Process and unpack the downloaded asset
        if [ -n "$DOWNLOADED_PAYLOAD" ]; then
            case "$MATCHED_ASSET" in
                *.bin)
                    mv -f "$DOWNLOADED_PAYLOAD" "$TARGET_RELEASE_FILE"
                    ;;
                *.tar.gz|*.tgz)
                    echo -e " 📦 Unpacking tar.gz archive..."
                    EXTRACT_TMP=$(mktemp -d)
                    tar -xzf "$DOWNLOADED_PAYLOAD" -C "$EXTRACT_TMP"
                    rm -f "$DOWNLOADED_PAYLOAD"

                    # Discover the binary inside archive root or nested folders
                    EXTRACTED_BIN=$(find "$EXTRACT_TMP" -type f \( -name "$BIN_NAME" -o -name "$APP_NAME" \) | head -n 1)
                    if [ -n "$EXTRACTED_BIN" ]; then
                        mv -f "$EXTRACTED_BIN" "$TARGET_RELEASE_FILE"
                    fi
                    rm -rf "$EXTRACT_TMP"
                    ;;
                *.zip)
                    if ! command -v unzip &> /dev/null; then
                        echo -e " ❌ ${RED}'unzip' utility is required to extract zip releases.${NC}"
                        show_install_hint "unzip" "unzip" "unzip" "unzip"
                        rm -f "$DOWNLOADED_PAYLOAD"
                    else
                        echo -e " 📦 Unpacking zip archive..."
                        EXTRACT_TMP=$(mktemp -d)
                        unzip -q -o "$DOWNLOADED_PAYLOAD" -d "$EXTRACT_TMP"
                        rm -f "$DOWNLOADED_PAYLOAD"

                        EXTRACTED_BIN=$(find "$EXTRACT_TMP" -type f \( -name "$BIN_NAME" -o -name "$APP_NAME" \) | head -n 1)
                        if [ -n "$EXTRACTED_BIN" ]; then
                            mv -f "$EXTRACTED_BIN" "$TARGET_RELEASE_FILE"
        fi
                        rm -rf "$EXTRACT_TMP"
                    fi
                    ;;
            esac

            # Final validation of extracted binary
            if [ -f "$TARGET_RELEASE_FILE" ] && [ -s "$TARGET_RELEASE_FILE" ]; then
            chmod +x "$TARGET_RELEASE_FILE"
            BIN_FILE="$TARGET_RELEASE_FILE"
                echo -e "   -> ${GREEN}✔ Binary deployed to: $BIN_FILE${NC}"
            else
                echo -e "${RED}❌ Failed to extract valid executable binary from release archive.${NC}"
            fi
        else
            echo -e "${RED}❌ No release assets found at '${RELEASE_BASE_URL}'.${NC}"
            echo -e "   Checked: ${CANDIDATE_ASSETS[*]}"
        fi
    fi

    # Fallback to manual copy instructions if download was skipped or unsuccessful
    if [ -z "$BIN_FILE" ]; then
        echo ""
        echo -e "  💡 ${BOLD}Manual Download Instructions:${NC}"
        echo -e "     1. Download '${BIN_NAME}', '${BIN_STEM}.tar.gz', or '${BIN_STEM}.zip' from:"
        echo -e "        ${BLUE}https://github.com/<OWNER>/<REPO>/releases/tag/${APP_VERSION}${NC}"
        echo -e "     2. Place or extract the binary into '${BIN_PATH}/':"
        echo -e "        ${BOLD}cp \"$DEFAULT_DOWNLOAD_FILE\" \"$TARGET_RELEASE_FILE\" && chmod +x \"$TARGET_RELEASE_FILE\"${NC}"
        echo ""

        while true; do
            read -r -p "$(echo -e " ⏳ Press ${GREEN}[Enter]${NC} once copied to '${BIN_PATH}/' (or type '${RED}exit${NC}' to cancel): ")" user_input

            if [[ "$user_input" =~ ^[Ee][Xx][Ii][Tt]$ ]]; then
                log_user_aborted
                log_end_process
                exit 0
            fi

            if [ -f "$TARGET_RELEASE_FILE" ] && [ -s "$TARGET_RELEASE_FILE" ]; then
                chmod +x "$TARGET_RELEASE_FILE"
                BIN_FILE="$TARGET_RELEASE_FILE"
                echo -e "   -> ${GREEN}✔ Detected binary at: $BIN_FILE${NC}"
                break
            elif [ -f "$DEFAULT_DOWNLOAD_FILE" ] && [ -s "$DEFAULT_DOWNLOAD_FILE" ]; then
                echo -e "   📦 Found binary in ~/Downloads! Copying to $TARGET_RELEASE_FILE..."
                cp -f "$DEFAULT_DOWNLOAD_FILE" "$TARGET_RELEASE_FILE"
                chmod +x "$TARGET_RELEASE_FILE"
                BIN_FILE="$TARGET_RELEASE_FILE"
                echo -e "   -> ${GREEN}✔ Copied and validated binary: $BIN_FILE${NC}"
                break
            else
                echo -e "   ${YELLOW}⚠ Could not find valid '${BIN_NAME}' in '${BIN_PATH}/' or '${HOME}/Downloads'. Please verify and try again.${NC}"
            fi
        done
    fi
fi

chmod +x "$BIN_FILE"

echo "📦 Step 1: Installing binary to $TARGET_BIN..."
if [ -w "/usr/local/bin" ]; then
    cp -f "$BIN_FILE" "$TARGET_BIN"
    chmod +x "$TARGET_BIN"
else
    echo "🔐 Elevated permissions required to copy to /usr/local/bin:"
    sudo cp -f "$BIN_FILE" "$TARGET_BIN"
    sudo chmod +x "$TARGET_BIN"
fi
echo -e "   -> ${GREEN}✔ Binary successfully placed at: $TARGET_BIN${NC}"

# =====================================================================================================================
# 4. Deploy system-wide icons
# =====================================================================================================================
log_separator
echo "🎨 Step 2: Registering system-wide icons..."

ICON_SRC=""
if [ -f "$REPO_ROOT/assets/icons/$ICON_NAME" ]; then
    ICON_SRC="$REPO_ROOT/assets/icons/$ICON_NAME"
elif [ -f "$REPO_ROOT/icons/$ICON_NAME" ]; then
    ICON_SRC="$REPO_ROOT/icons/$ICON_NAME"
elif [ -f "$REPO_ROOT/$ICON_NAME" ]; then
    ICON_SRC="$REPO_ROOT/$ICON_NAME"
elif [ -f "$SCRIPT_DIR/$ICON_NAME" ]; then
    ICON_SRC="$SCRIPT_DIR/$ICON_NAME"
fi

if [ -n "$ICON_SRC" ]; then
    NEW_ICON_HASH=$(get_file_sha256 "$ICON_SRC")
    # Verify hash against system-wide icon installation target
    SYS_ICON_HASH=$(get_file_sha256 "$SYS_PIXMAPS_DIR/$ICON_NAME")

    if [ "$NEW_ICON_HASH" != "$SYS_ICON_HASH" ]; then
        echo "🔐 Deploying icons to $SYS_ICON_DIR..."

        # Deployed fallback icon to /usr/share/pixmaps for desktop menu compatibility
        sudo mkdir -p "$SYS_PIXMAPS_DIR"
        sudo cp -f "$ICON_SRC" "$SYS_PIXMAPS_DIR/$ICON_NAME"

        # Deployed icons across standard system-wide hicolor size trees using sudo
        for size in "${HICOLOR_SIZES[@]}"; do
            target_hicolor="$SYS_HICOLOR_DIR/$size/apps"
            sudo mkdir -p "$target_hicolor"
            sudo cp -f "$ICON_SRC" "$target_hicolor/$ICON_NAME"
        done
        ICON_UPDATED=true
        echo -e "   -> ${GREEN}✔ Icons successfully deployed across /usr/share/icons/hicolor/ sizes.${NC}"
    else
        echo -e "   -> 🎨 ${GREEN}System icons are identical (Skipped overwrite).${NC}"
    fi
else
    echo -e "   -> ⚠ ${YELLOW}[Warning] Icon file not found. System may display fallback icon.${NC}"
fi

# =====================================================================================================================
# 5. Register system-wide desktop entry & isolate user configuration
# =====================================================================================================================
log_separator
echo -e "🖥️  ${BOLD}Registering system-wide desktop launcher entry...${NC}"

# Initialized private user-local configuration directory with strict 700 owner permissions
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

TEMP_DESKTOP=$(mktemp)

# Fixed syntax by properly referencing $TEMP_DESKTOP variable in heredoc redirection
cat <<EOF > "$TEMP_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
GenericName=Digital Archive & Metadata Manager
Comment=Secure, PII-safe digital archive, deduplication, and metadata manager
Exec=$TARGET_BIN
Icon=$APP_NAME
Categories=Utility;Archiving;FileManager;
Terminal=false
StartupWMClass=$APP_NAME
StartupNotify=true
EOF

NEW_DESKTOP_HASH=$(get_file_sha256 "$TEMP_DESKTOP")
SYS_DESKTOP_HASH=$(get_file_sha256 "$DESKTOP_FILE")

if [ "$NEW_DESKTOP_HASH" != "$SYS_DESKTOP_HASH" ]; then
    echo "🔐 Elevating permissions to install launcher to $SYS_APP_DIR..."
    # Installed desktop launcher to /usr/share/applications with standard 644 permissions
    sudo mkdir -p "$SYS_APP_DIR"
    sudo rm -f "$DESKTOP_FILE"
    sudo mv -f "$TEMP_DESKTOP" "$DESKTOP_FILE"
    sudo chmod 644 "$DESKTOP_FILE"
    DESKTOP_UPDATED=true
    echo -e "   -> ${GREEN}✔ Registered system-wide desktop launcher: $DESKTOP_FILE${NC}"

    # Maintained local repository mirror copy if config/ directory is present
    if [ -d "$REPO_ROOT/config" ]; then
        cp -f "$DESKTOP_FILE" "$REPO_ROOT/config/" 2>/dev/null || true
        echo -e "   -> ${GREEN}✔ Desktop Entry mirrored to $REPO_ROOT/config/${NC}"
    fi
else
    rm -f "$TEMP_DESKTOP"
    echo -e "   -> ${YELLOW}Desktop launcher entry is identical (Skipped overwrite).${NC}"
fi

# =====================================================================================================================
# 6. System cache refresh
# =====================================================================================================================
log_separator
if [ "$DESKTOP_UPDATED" = true ] || [ "$ICON_UPDATED" = true ]; then
    echo "🔄 Modified launcher assets detected. Refreshing system caches..."
    if command -v update-desktop-database &> /dev/null; then
        echo -e "   -> 🔄 Refreshing system desktop application database..."
        # Updated system application registry using sudo
        sudo update-desktop-database "$SYS_APP_DIR" || true
    fi

    # Fixed undefined variable $EXEC_CMD by replacing with $TARGET_BIN
    echo -e "   -> ${GREEN}✔ Registered desktop shortcut launching: $TARGET_BIN.${NC}"

    if command -v gtk-update-icon-cache &> /dev/null; then
        echo -e "   -> 🔄 Refreshing system GTK icon cache database..."
        # Refreshed system-wide GTK icon cache using sudo
        sudo gtk-update-icon-cache -f -t "$SYS_HICOLOR_DIR" 2>/dev/null || true
    fi

    echo -e "   -> ${GREEN}✔ Icon Cache database updated.${NC}"
else
    echo -e "✅ ${GREEN}No desktop or icon changes detected — System caches preserved intact.${NC}"
fi

echo "======================================================================"
echo -e "${GREEN}${BOLD}✅ Installation Completed Successfully!${NC}"
echo "   - Binary Installed : $TARGET_BIN"
echo "   - Desktop Launcher : $DESKTOP_FILE"
echo "   - User Config Dir  : $CONFIG_DIR (Mode 700)"
echo ""
echo "🚀 You can now launch digiArchive from your application menu or by running:"
echo "   $APP_NAME"
echo "======================================================================"