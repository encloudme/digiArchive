#!/usr/bin/env bash
# ==============================================================================
# digiArchive v5.0.5 - Automated Linux Installation Script (Re-wired)
# ==============================================================================
set -eo pipefail

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
APP_VERSION="v5.0.5"
BIN_NAME="${APP_NAME}-linux-x86_64.bin"

# 1. New Subfolder Structure in /usr/local/bin/digiArchive/
TARGET_DIR="/usr/local/bin/$APP_NAME"
TARGET_BIN="$TARGET_DIR/$BIN_NAME"

# 2. System Share Directory for Heavy Assets (Video)
SYS_SHARE_DIR="/usr/local/share/$APP_NAME"

# 3. Moved desktop launcher directory to system-wide location (requires sudo)
SYS_APP_DIR="/usr/share/applications"
DESKTOP_FILE="$SYS_APP_DIR/digital-archive.desktop"

# 4. Retained user-local configuration path to preserve private user data
CONFIG_DIR="$HOME/.config/digital-archive"

# 5. Switched icon directories to system-wide FreeDesktop standards (requires sudo)
SYS_ICON_DIR="/usr/share/icons"
SYS_HICOLOR_DIR="$SYS_ICON_DIR/hicolor"
SYS_PIXMAPS_DIR="/usr/share/pixmaps"

# 6. GNOME standard icon sizes
HICOLOR_SIZES=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "512x512")

# 7. Helper function to compute SHA-256 hash safely
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

# 8. Detect package manager once at script start
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

# 9. Helper function to print a tailored install hint and optionally execute it
show_install_hint() {
    local tool_name="$1"
    local deb_pkg="$2"
    local fed_pkg="$3"
    local arch_pkg="$4"
    local install_cmd=""

    # 9.1. Resolve the exact command based on the detected package manager
    case "$PKG_MGR" in
        apt)
            install_cmd="sudo apt update && sudo apt install -y ${deb_pkg}"
            ;;
        dnf)
            install_cmd="sudo dnf install -y ${fed_pkg}"
            ;;
        pacman)
            install_cmd="sudo pacman -S --noconfirm ${arch_pkg}"
            ;;
        *)
            install_cmd=""
            ;;
    esac

    # 9.2. Display the installation advice
    echo -e "  💡 ${BOLD}Recommended command to install ${tool_name}:${NC}"
    if [[ -n "$install_cmd" ]]; then
        echo -e "     ${BOLD}${install_cmd}${NC}"
    else
        echo -e "     - Debian/Ubuntu:  sudo apt install ${deb_pkg}"
        echo -e "     - Fedora/RHEL:    sudo dnf install ${fed_pkg}"
        echo -e "     - Arch Linux:     sudo pacman -S ${arch_pkg}"
    fi
    echo ""

    # 9.3. Prompt and execute if a package manager was recognized and shell is interactive
    if [[ -n "$install_cmd" ]] && [ -t 0 ]; then
        read -r -p "  Would you like to run this command now? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy](es)?$ ]]; then
            echo -e "  🚀 Running: ${BOLD}${install_cmd}${NC}\n"
            if eval "$install_cmd"; then
              echo -e " ✔ ${CYAN}${tool_name} installed successfully.\n"
            else
              echo -e " ❌ Failed to install ${tool_name}.\n"
            fi
        else
            echo -e "  Skipped installation.\n"
        fi
    fi
}

DESKTOP_UPDATED=false
ICON_UPDATED=false

log_separator() { echo -e "${BLUE}${BOLD}==============================================================================${NC}"; }
log_end_process() { echo -e "${GREEN}${BOLD}==============================================================================${NC}"; }
log_user_aborted() { echo -e " 🛑 ${RED}${BOLD}[Cancel] Installation aborted by user.${NC}" ; }

log_separator
echo -e "${BLUE}${BOLD}         🏛️  ${APP_NAME} ${APP_VERSION} (Linux x86_64) Installation        ${NC}"
log_separator

# =====================================================================================================================
# I. Guardrail: Prevent running the whole script as root / sudo
# =====================================================================================================================
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ [Error] Do NOT run this installer directly with 'sudo' or as the root user.${NC}"
    echo -e "   Running as root causes user configuration files to be created with root-only permissions."
    echo -e "   💡 ${BOLD}Please run as your regular user:${NC} ./${0##*/}"
    log_end_process
    exit 1
fi

read -r -p "$(echo -e "📥 ${GREEN}${BOLD}Install ${APP_NAME} (${APP_VERSION})? (y/N): ${NC}")" choice
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    log_user_aborted
    log_end_process
    exit 0
fi

# =====================================================================================================================
# II. Validate sudo credentials upfront
# =====================================================================================================================
echo -e "\n🔐 ${BOLD}Validating administrative (sudo) privileges...${NC}"
echo -e "(Needed for copying files to /usr/local/ and icons to /usr/share/) \n"

if ! sudo -v; then
    echo -e "\n${RED}❌ [Error] Sudo authentication failed.${NC}"
    log_end_process
    exit 1
fi
echo -e "   -> ${GREEN}✔ Sudo access verified.${NC}"

# =====================================================================================================================
# III. Resolve project root directory relative to this script
# =====================================================================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"    #repo_root/installers
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"                     #repo_root
BIN_PATH="$REPO_ROOT/releases"                                #repo_root/releases

# =====================================================================================================================
# IV. Definitive Pre-installation Update & Dependency Installation (GStreamer & Mesa/OpenGL)
# =====================================================================================================================
echo -e ""
log_separator
echo -e "${BOLD}🔄 Step 1: Updating package lists and installing multimedia & acceleration runtimes...${NC}\n"
sudo apt-get update
sudo apt-get install -y --show-progress \
  libgstreamer1.0-0 \
  libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-libav \
  gstreamer1.0-gl \
  libgl1-mesa-dev 2>&1 | tee apt-install.log


echo -e ""
log_separator
echo -e "${BOLD}📦 Step2: Installing modern Mesa/OpenGL software fallback runtimes...${NC}\n"
sudo apt-get install -y --show-progress \
  libopengl0 libglx-mesa0 libgl1-mesa-dri 2>&1 | tee -a apt-install.log


echo -e ""
log_separator
echo -e "${BOLD}🔍 Step 3: System dependency audit...${NC}\n"

# 1. Check Python3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED} ❌ [Error] Python3 is not installed on your system.${NC}"
    log_end_process
    exit 1
fi

# 2. Check ADB
if ! command -v adb &> /dev/null; then
    echo -e " ⚠ ${YELLOW}[Warning] 'adb' was not detected on your system.${NC}"
    show_install_hint "adb" "adb android-tools-adb" "android-tools" "android-tools"
else
    echo -e " ✅ ${GREEN}ADB${NC} connectivity protocols detected."
fi

# 3. Check SQLite3
if ! command -v sqlite3 &> /dev/null; then
    echo -e " ⚠ ${YELLOW}[Warning] 'sqlite3' CLI utility was not detected.${NC}"
    show_install_hint "sqlite3" "sqlite3" "sqlite" "sqlite"
else
    echo -e " ✅ ${GREEN}SQLite3${NC} CLI utility detected."
fi

# 4. Check GStreamer 1.0 Runtime (Required for Video Splash)
if ! ldconfig -p 2>/dev/null | grep -q "libgstreamer-1.0" && ! command -v gst-launch-1.0 &> /dev/null; then
    echo -e " ⚠ ${YELLOW}[Warning] GStreamer 1.0 multimedia libraries were not fully detected.${NC}"
    show_install_hint "GStreamer 1.0" \
        "libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 gstreamer1.0-plugins-good" \
        "gstreamer1 gstreamer1-plugins-base gstreamer1-plugins-good" \
        "gstreamer gst-plugins-base gst-plugins-good"
else
    echo -e " ✅ ${GREEN}Multimedia Backend:${NC} GStreamer 1.0 detected."
fi


# Not required for standalone executions.
## 5. Check for PySide6 & Python Runtime (Source execution & Dev tools)
#echo -e "\n${BLUE}🔍 Verifying Python runtime and GUI libraries (PySide6)...${NC}"
#if command -v python3 &> /dev/null; then
#    if ! python3 -c "import PySide6" &> /dev/null; then
#        echo -e " ⚠ ${YELLOW}[Notice] PySide6 is not installed in the system Python environment.${NC}"
#        echo -e "    ${CYAN}Note:${NC} The standalone binary bundles PySide6, but running source tools, CLI utilities, or tests requires it."
#
#        REQ_FILE=""
#        if [ -f "$REPO_ROOT/requirements.txt" ]; then
#            REQ_FILE="$REPO_ROOT/requirements.txt"
#        elif [ -f "$SCRIPT_DIR/requirements.txt" ]; then
#            REQ_FILE="$SCRIPT_DIR/requirements.txt"
#        fi
#
#        if [ -n "$REQ_FILE" ]; then
#            read -r -p "$(echo -e "${BLUE} ❔ Would you like to install required packages from requirements.txt now? (y/N): ${NC}")" req_choice
#            if [[ "$req_choice" =~ ^[Yy]$ ]]; then
#                echo -e "📦 Installing packages from $REQ_FILE..."
#                python3 -m pip install -r "$REQ_FILE" || pip3 install -r "$REQ_FILE" || true
#            fi
#        else
#            echo -e "  💡 To install PySide6 manually: ${BOLD}pip install PySide6${NC}\n"
#        fi
#    else
#        echo -e " ✅ ${GREEN}GUI Framework:${NC} PySide6 detected in Python environment."
#    fi
#fi

# =====================================================================================================================
# V. Locate binary executable
# =====================================================================================================================
echo -e ""
log_separator
echo -e "📦 ${BOLD}Step 4: Locating application binary...${NC}\n"


# Base release URL template
RELEASE_BASE_URL="https://github.com/encloudme/digiArchive/releases/download/${APP_VERSION}"

DEFAULT_DOWNLOAD_FILE="$HOME/Downloads/$BIN_NAME"
TARGET_RELEASE_FILE="$BIN_PATH/$BIN_NAME"
BIN_STEM="${BIN_NAME%.bin}"

# Check local candidate paths first (file exists and size > 0)
BIN_FILE=""
if [ -f "$BIN_PATH/$BIN_NAME" ] && [ -s "$BIN_PATH/$BIN_NAME" ]; then
    BIN_FILE="$BIN_PATH/$BIN_NAME"
    echo -e "   -> ${GREEN}✔ Asset found! ${BIN_FILE}..."
elif [ -f "$SCRIPT_DIR/$BIN_NAME" ] && [ -s "$SCRIPT_DIR/$BIN_NAME" ]; then
    BIN_FILE="$SCRIPT_DIR/$BIN_NAME"
    echo -e "   -> ${GREEN}✔ Asset found! ${BIN_FILE}..."
elif [ -f "$REPO_ROOT/$BIN_NAME" ] && [ -s "$REPO_ROOT/$BIN_NAME" ]; then
    BIN_FILE="$REPO_ROOT/$BIN_NAME"
    echo -e "   -> ${GREEN}✔ Asset found! ${BIN_FILE}..."
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
            echo -e " 🔍 Checking asset: ${BLUE}${asset}${NC}."
            echo -e " Please wait, this may take a while..."

            # 1. Silently check if the asset URL exists (HTTP 200)
            EXISTS=false
            if command -v curl &> /dev/null; then
                if curl -sI -fL "$candidate_url" &>/dev/null; then
                    EXISTS=true
                    echo -e "   -> ${GREEN}✔ Asset found! Downloading ${asset} (large files may take a moment)...${NC}"
                fi
            elif command -v wget &> /dev/null; then
                if wget --spider -q "$candidate_url" &>/dev/null; then
                    EXISTS=true
                    echo -e "   -> ${GREEN}✔ Asset found! Downloading ${asset} (large files may take a moment)...${NC}"
                fi
            fi

            # 2. Use -f to fail on 404, -L to follow GitHub CDN 302 redirects
            if [ "$EXISTS" = true ]; then
#                echo -e "   -> ${GREEN}✔ Downloading ${asset}...${NC}"
                TEMP_DOWNLOAD=$(mktemp)
                DOWNLOAD_STATUS=false

                if command -v curl &> /dev/null; then
                        # Replace --silent with --progress-bar lets curl print a clean transfer meter to stderr
                        if curl -fL --progress-bar --show-error "$candidate_url" -o "$TEMP_DOWNLOAD" 2>/dev/null; then
                            DOWNLOAD_STATUS=true
                        fi
                elif command -v wget &> /dev/null; then
                        # Removing -q lets wget show its native progress bar
                        if wget -O "$TEMP_DOWNLOAD" "$candidate_url" 2>/dev/null; then
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
                echo -e "   -> ${GREEN}✔ Binary deployed to: $TARGET_BIN${NC}"
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
        echo -e "        ${BLUE}https://github.com/encloudme/digiArchive/releases/tag/${APP_VERSION}${NC}"
        echo -e "     2. Place or extract the binary into '${BIN_PATH}/' or Downloads directory:"
        echo -e "        ${BOLD}cp \"$DEFAULT_DOWNLOAD_FILE\" \\\\"
        echo -e "        ${BOLD}   \"$TARGET_RELEASE_FILE\" \\\\"
        echo -e "        ${BOLD}   && chmod +x \"$TARGET_RELEASE_FILE\"${NC}"
        echo ""

        while true; do
            read -r -p "$(echo -e " ⏳ Press ${GREEN}[Enter]${NC} once copied to '${BIN_PATH}/' / '~/Downloads' \
             (or type '${RED}exit${NC}' to cancel): ")" user_input

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
                echo -e "   ${YELLOW}⚠ Could not find valid '${BIN_NAME}' in '${BIN_PATH}/' or '${HOME}/Downloads'. \
                 Please verify and try again.${NC}"
            fi
        done
    fi
fi

chmod +x "$BIN_FILE"

# =====================================================================================================================
# VI. Deploy Subfolder Binary Structure, Shared Video Assets, and Schema File
# =====================================================================================================================
log_separator
echo -e "📦 Step 5: Deploying binary bundle and assets to $TARGET_DIR..."
sudo mkdir -p "$TARGET_DIR"

# Copy binary file
sudo cp -f "$BIN_FILE" "$TARGET_BIN"
sudo chmod +x "$TARGET_BIN"

# Copy assets folder directly into /usr/local/bin/digiArchive/assets
if [ -d "$REPO_ROOT/assets" ]; then
    sudo cp -rf "$REPO_ROOT/assets" "$TARGET_DIR/"
    echo -e "   -> ${GREEN}✔ Assets folder bundled into: $TARGET_DIR/assets${NC}"
fi

# Copy video file specifically to /usr/local/share/digiArchive
echo -e "\n📂 Step 6: Copying video file to shared directory $SYS_SHARE_DIR..."
sudo mkdir -p "$SYS_SHARE_DIR"
if [ -f "$REPO_ROOT/assets/welcome/digiArchive_launch.mp4" ]; then
    sudo cp -f "$REPO_ROOT/assets/welcome/digiArchive_launch.mp4" "$SYS_SHARE_DIR/"
    echo -e "   -> ${GREEN}✔ Video splash asset placed at: $SYS_SHARE_DIR/digiArchive_launch.mp4${NC}"
elif [ -f "$BIN_PATH/assets/welcome/digiArchive_launch.mp4" ]; then
    sudo cp -f "$BIN_PATH/assets/welcome/digiArchive_launch.mp4" "$SYS_SHARE_DIR/"
    echo -e "   -> ${GREEN}✔ Video splash asset placed at: $SYS_SHARE_DIR/digiArchive_launch.mp4${NC}"
else
    echo -e "   -> ${YELLOW}⚠ [Warning] Video splash asset not found locally. Skipping copy...${NC}"
fi


# Copy schema file specifically to /usr/local/share/digiArchive
echo -e "\n🗄️  Step 7: Copying schema file to application directory $TARGET_DIR..."

SCHEMA_SRC=""
if [ -f "$REPO_ROOT/database/schema.sql" ]; then
    SCHEMA_SRC="$REPO_ROOT/database/schema.sql"
elif [ -f "$SCRIPT_DIR/database/schema.sql" ]; then
    SCHEMA_SRC="$SCRIPT_DIR/database/schema.sql"
elif [ -f "$BIN_PATH/database/schema.sql" ]; then
    SCHEMA_SRC="$BIN_PATH/database/schema.sql"
fi

if [ -n "$SCHEMA_SRC" ]; then
    sudo cp -f "$SCHEMA_SRC" "$TARGET_DIR/schema.sql"
    sudo chmod 644 "$TARGET_DIR/schema.sql"
    echo -e "   -> ${GREEN}✔ Schema file successfully deployed to: $TARGET_DIR/schema.sql${NC}"
else
    echo -e "   -> ⚠ ${YELLOW}[Warning] database/schema.sql not found in repo source paths. Skipping schema deployment.${NC}"
fi

# =====================================================================================================================
# VII. Deploy system-wide icons
# =====================================================================================================================

echo -e "\n🎨 Step 8: Registering system-wide icons..."

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
        echo -e "🔐 Deploying icons to $SYS_ICON_DIR..."

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
        echo -e "   -> ${GREEN}✔ System icons are identical (Skipped overwrite).${NC}"
    fi
else
    echo -e "   -> ⚠ ${YELLOW}[Warning] Icon file not found. System may display fallback icon.${NC}"
fi

# =====================================================================================================================
# VIII. Register Desktop Entry with Hardware Acceleration Environment Variable
# =====================================================================================================================
echo -e ""
log_separator
echo -e "🖥️  ${BOLD}Step 9: Registering system-wide desktop launcher entry (with VM acceleration flags)...${NC}"

# Initialized private user-local configuration directory with strict 700 owner permissions
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

TEMP_DESKTOP=$(mktemp)

# Note: We set QSG_RHI_BACKEND=software in the Exec line to guarantee smooth VM rendering!
cat <<EOF > "$TEMP_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
GenericName=Digital Archive & Metadata Manager
Comment=Secure, PII-safe digital archive, deduplication, and metadata manager
Exec=env QSG_RHI_BACKEND=software $TARGET_BIN
Icon=$APP_NAME
Categories=Utility;Archiving;FileManager;
Terminal=false
StartupWMClass=$APP_NAME
StartupNotify=true
EOF

NEW_DESKTOP_HASH=$(get_file_sha256 "$TEMP_DESKTOP")
SYS_DESKTOP_HASH=$(get_file_sha256 "$DESKTOP_FILE")

if [ "$NEW_DESKTOP_HASH" != "$SYS_DESKTOP_HASH" ]; then
    echo -e "🔐 Elevating permissions to install launcher to $SYS_APP_DIR..."
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
# IX. System cache refresh
# =====================================================================================================================
echo -e ""
log_separator
if [ "$DESKTOP_UPDATED" = true ] || [ "$ICON_UPDATED" = true ]; then
    echo -e "🔄 Step 10: Modified launcher assets detected. Refreshing system caches..."
    if command -v update-desktop-database &> /dev/null; then
        echo -e "   -> 🔄 Refreshing system desktop application database..."
        # Updated system application registry using sudo
        sudo update-desktop-database "$SYS_APP_DIR" || true
    fi

    # Fixed undefined variable $EXEC_CMD by replacing with $TARGET_BIN
    echo -e "   -> ${GREEN}✔ Registered desktop shortcut launching: $TARGET_BIN.${NC}\n"

    if command -v gtk-update-icon-cache &> /dev/null; then
        echo -e "   -> 🔄 Refreshing system GTK icon cache database..."
        # Refreshed system-wide GTK icon cache using sudo
        sudo gtk-update-icon-cache -f -t "$SYS_HICOLOR_DIR" 2>/dev/null || true
    fi

    echo -e "   -> ${GREEN}✔ Icon Cache database updated.${NC}"
else
    echo -e "✅ ${GREEN}Step 10: No desktop or icon changes detected — System caches preserved intact.${NC}\n"
fi

# =====================================================================================================================
# 7. Run Highlights
# =====================================================================================================================
log_separator
echo -e "${GREEN}${BOLD}✅ Installation Completed Successfully!${NC}"
echo -e ""
echo -e "  - Binary Directory : $TARGET_DIR"
echo -e "  - Shared Video     : $SYS_SHARE_DIR/digiArchive_launch.mp4"
echo -e "  - Desktop Launcher : $DESKTOP_FILE"
echo -e "                       (with QSG_RHI_BACKEND=software)"
echo -e ""
echo -e "${CYAN}${BOLD}🏛️  You can now launch digiArchive from your application menu!"
log_end_process