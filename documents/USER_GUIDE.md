### 🏛️ digiArchive v5.1.0 — Detailed User Guide
Welcome to the **digiArchive** user guide. This document provides step-by-step instructions for installing, configuring, operating, and maintaining your digital archive and metadata catalog.

---

#### 📚 Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Hardware & Software Prerequisites](#2-hardware--software-prerequisites)
3. [Installation & First-Time Launch](#3-installation--first-time-launch)
4. [Two-Factor Authentication (2FA) Mobile Setup](#4-two-factor-authentication-2fa-mobile-setup)
    * [4.1 Why Mobile 2FA is Required](#41-why-mobile-2fa-is-required)
    * [4.2 Step-by-Step Mobile Pairing Walkthrough](#42-step-by-step-mobile-pairing-walkthrough)
    * [4.3 Vault Security & Database Credentials (FR-18)](#43-vault-security--database-credentials-fr-18)
    * [4.4 Authenticating Sensitive Administrative Actions](#44-authenticating-sensitive-administrative-actions)
    * [4.5 TOTP Troubleshooting & Clock Drift](#45-totp-troubleshooting--clock-drift)
5. [User Interface Navigation](#5-user-interface-navigation)
6. [Core Workflows](#6-core-workflows)
    * [6.1 Device Onboarding & Hardware Discovery](#61-device-onboarding--hardware-discovery)
    * [6.2 Running Ingestion & Sync Sweeps](#62-running-ingestion--sync-sweeps)
    * [6.3 Duplicate Resolution & Hygiene Sweeps](#63-duplicate-resolution--hygiene-sweeps)
    * [6.4 Catalog Hot-Backups & Point-in-Time Rollback](#64-catalog-hot-backups--point-in-time-rollback)
7. [CLI Maintenance & Dev QR Utilities](#7-cli-maintenance--dev-qr-utilities)
8. [Troubleshooting & Permission Fixes](#8-troubleshooting--permission-fixes)

---

#### 1. Architecture Overview
digiArchive strictly separates **physical media storage** from **logical database indexing**:
```text
+-----------------------------------------------------------------------+
|                       MASTER VAULT (VAULT_ROOT)                       |
|  ├── .archive/catalog.db        <-- Central SQLite Index ('Brain')    |
|  │     ├── vault_security       <-- Admin hash, TOTP secret & UUID    |
|  │     ├── asset_inventory      <-- Observed physical occurrences     |
|  │     └── files                <-- Master files (SHA-256 fixity)     |
|  ├── MEDIA_STAGING/             <-- Non-destructive Pull Staging      |
|  ├── _BIN/                      <-- Quarantine Directory              |
|  └── .archive/backups/          <-- GFS Hot-Backup Storage            |
+-----------------------------------------------------------------------+
```

##### Physical Occurrences vs. Logical Master Files
* **Physical Occurrence (`asset_inventory`)**: Records a file observed at a specific path on an attached device (e.g., `/sdcard/DCIM/IMG_001.jpg` on `PHONE_A73`).
* **Logical File (`files`)**: Represents unique master file content, uniquely identified by its cryptographic **SHA-256 hash**.
* **Asset Mapping (`asset_map`)**: Links physical occurrences to the logical master file. If three attached devices hold identical media, digiArchive registers three physical occurrences mapped to one logical record, preventing redundant physical duplicate storage.
* **Vault Security (`vault_security`)**: Embedded security table inside `catalog.db` storing `db_uuid` (immutable UUID v4), `admin_hash`, `totp_secret`, and `vault_name`.

---

#### 2. Hardware & Software Prerequisites
Before launching digiArchive, ensure your environment meets the following specifications:

##### 🖥️ Hardware Requirements
* **Host Workstation**: 64-bit x86_64 PC (2.0 GHz dual-core CPU, 2 GB RAM minimum; 4 GB+ RAM recommended). Storage requirements depend on archive media volume.
* **Mobile Smartphone or Tablet**: **Required.** Android or iOS device with a working camera (for scanning setup QR codes) or manual text entry.
* **Cables & Ports**: USB 2.0 or 3.0+ ports with standard data sync cables for connected source devices.

##### 📦 Software Requirements
* **Operating System**: Linux x86_64 (Ubuntu 22.04 LTS+, Debian 12+, Fedora 38+, or compatible distribution) running X11 or Wayland.
* **Mobile Authenticator App (RFC 6238 TOTP compliant)**:
    * **Aegis Authenticator** (Android, Open Source — Recommended)
    * **2FAS** (Android / iOS, Open Source)
    * **Google Authenticator** (Android / iOS)
    * **Microsoft Authenticator** (Android / iOS)
    * **Bitwarden** (Integrated TOTP)
* **Optional System Utilities**: `gstreamer1.0` runtime for video splash playback, `android-tools-adb` for automated Android USB detection (`sudo apt install android-tools-adb`).

---

#### 3. Installation & First-Time Launch
##### Installing on Linux
1. Open a terminal in the cloned repository directory.
2. Execute the automated installer script:
```bash
bash installers/install-digiarchive.sh
```
*This copies the standalone binary to `/usr/local/bin/digiArchive`, installs menu icons, and registers desktop entries.*
3. Launch digiArchive from your desktop application launcher or run:
```bash
digiArchive
```

---

#### 4. Two-Factor Authentication (2FA) Mobile Setup

##### 4.1 Why Mobile 2FA is Required
digiArchive enforces an offline security perimeter to protect your digital vault against accidental deletions, unauthorized database rollbacks, and catalog overwrites.
All sensitive administrative actions require a **6-digit Time-Based One-Time Password (TOTP)** generated on your smartphone. Because TOTP runs completely offline using mathematical cryptography (RFC 6238), neither your workstation nor your phone requires an active internet connection.

##### 4.2 Step-by-Step Mobile Pairing Walkthrough
When you launch digiArchive with a newly initialized database or access the security vault for the first time:
1. **Trigger Setup**: The application automatically displays the **2FA Security Setup Wizard** dialog (`InitialSetupDialog`).
2. **Open Authenticator App on Mobile**:
    * Open your chosen mobile authenticator app (e.g., Aegis, 2FAS, Google Authenticator).
    * Tap the **Add Account / +** button.
3. **Scan QR Code or Enter Secret**:
    * **Option A (Camera Scan)**: Select **Scan QR Code** in the app and point your phone camera at the QR code displayed on the digiArchive screen.
    * **Option B (Manual Entry)**: Select **Enter Key Manually**, set the account name to `admin (catalog.db)`, and copy the Base32 secret string displayed below the QR code.
4. **Save Account**: Confirm and save the entry in your mobile authenticator. The app will begin generating a new 6-digit verification code every 30 seconds.
5. **Verify Pairing**:
    * Enter the current 6-digit code shown in your phone app into the **Verification Code** input box in digiArchive.
    * Click **"Confirm & Lock Vault"**.

##### 4.3 Vault Security & Database Credentials (FR-18)
Under the FR-18 security specification:
* **Single Source of Truth**: All authentication parameters (`admin_hash`, `totp_secret`, `vault_name`, and immutable `db_uuid`) reside directly within `catalog.db` inside the `vault_security` table.
* **Auto-Migration**: Existing legacy setups automatically port credentials from `config.json` into `catalog.db` on application startup, pruning sensitive keys from disk config files.
* **Database Lineage Protection**: The `db_uuid` column is locked by SQLite triggers to prevent accidental modification or catalog spoofing.

##### 4.4 Authenticating Sensitive Administrative Actions
Your mobile authenticator is required whenever you perform high-impact operations:

| Administrative Operation                   | Why 2FA is Enforced                                                                           |
|:-------------------------------------------|:----------------------------------------------------------------------------------------------|
| **Catalog Snapshot Restoration**           | Prevents accidental overwrites of the live catalog with an older database state.              |
| **Point-in-Time Database Rollback**        | Protects transaction integrity before rolling back file occurrence records.                   |
| **Quarantine Bin Purge**                   | Ensures accidental deletion of quarantined files (`_BIN/`) cannot occur without verification. |
| **Database Re-initialization / DDL Reset** | Prevents catastrophic schema drops on active archives.                                        |

When performing any of the above actions:
1. digiArchive presents the **Secure Administration Challenge** modal.
2. Open your mobile authenticator app.
3. Enter the current 6-digit code for digiArchive and click **"Authenticate"**.

##### 4.5 TOTP Troubleshooting & Clock Drift
* **"Invalid One-Time Password"**:
    * TOTP calculates codes based on the current Unix timestamp in 30-second intervals.
    * Ensure your workstation system clock and smartphone clock are synchronized to network time (NTP). A system clock discrepancy of more than 60 seconds will cause verification to fail.
    * On Linux, synchronize your clock using:
```bash
sudo timedatectl set-ntp on
```
* **Lost Phone / Replacement**:
    * If you migrate to a new phone, run `python3 scripts/generate_dev_qr.py --db-path <path_to_catalog.db>` on your workstation to display a new QR code generated from your existing database secret.

---

###### 5. User Interface Navigation
digiArchive features a collapsible left-side navigation rail (expand 240px ↔ compact 68px via the **◀ / ☰ ** button):

*   **📊 Welcome & Storage Overview (Index 0):** Master vault status, storage capacity gauge, and quick-action navigation cards.
*   **📱 Devices & Hardware Discovery (Index 1):** Real-time category profile cards (PC, Tablet, Phone, USB) and physical hardware property inspector.
*   **⚡ Ingestion & Delta Sync (Index 2):** Two-pass non-destructive ingestion engine, Donut throughput visualizer, and **Export Excel Report** session exporter.
*   **🧹 Device Hygiene & Quarantine (Index 3):** Cache cleanup, temporary file removal, and survivor-guarded duplicate segregation into `_BIN/`.
*   **⏪ Restore Points & Rollback (Index 4):** Point-in-time recovery of quarantined assets and 2FA-shielded master database rollback.
*   **🏛️ File Vault Explorer (Index 5):** Interactive preservation and governance console. Contains four specialized sub-tabs:
    1. **🗂️ Vault Folder Governance:** Set folder status (`CANONICAL`), add subfolders, rename directories, inspect three-state health badges, and bind canonical contracts.
    2. **📄 File Browser & Operations:** Browse files in a 6-column grid with extension badges (`Ext`), filter by dynamic categories, inspect file metadata, view thumbnails, and execute bulk moves.
    3. **📜 Decision & Move History:** Audit historical move and rename events from `file_decision_history`, filter records, export reports (`.xlsx`/`.csv`), and execute 1-click transactional rollbacks.
    4. **🧭 File Lineage:** Trace full multi-device lifecycle events by SHA-256 hash across six distinct stages, auto-detect clipboard hashes, and export executive audit reports.
*   **⚙️ Settings & Database Operations (Index 6):** Vault path configuration, license terms, automated GFS crontab scheduling, and diagnostic logs.

---

#### 6. Core Workflows

##### 6.1 Device Onboarding & Hardware Discovery
1. Connect your source device (Android smartphone, tablet, USB storage drive, or external HDD) via USB.
2. Navigate to **📱 Devices & Sources**.
3. Click **"🔄 Refresh & Check Connected Hardware"**.
4. If an unregistered device is detected, the **Hardware Discovery Dialog** appears:
    * Select whether to associate the hardware with an existing profile or onboard it as a new device.
    * Provide an intuitive device label (e.g., Samsung Galaxy Tab S8, SanDisk 1TB SSD).

##### 6.2 Running Ingestion & Sync Sweeps
1. Navigate to **⚡ Ingestion Engine**.
2. Select your target **Source Device** from the dropdown menu.
3. Choose the directories to ingest (e.g., `/sdcard/DCIM`, `/sdcard/Pictures`).
4. Click **"Start Non-Destructive Sync"**.
5. The engine executes fixity checks:
    * SHA-256 checksums are calculated for all source files.
    * New unique files are staged in `MEDIA_STAGING/`.
    * Occurrences are recorded in `asset_inventory` and linked to master files in `asset_map`.
    * Source devices are accessed in read-only mode and are never modified.

##### 6.3 Duplicate Resolution & Hygiene Sweeps
1. Navigate to **🧹 Device Hygiene**.
2. Select **"Scan for Duplicates"**.
3. The scanner displays duplicate groups where multiple devices hold identical SHA-256 assets.
4. Choose an action policy (`KEEP_ONE`, `KEEP_ALL`, or `QUARANTINE`) and apply. Quarantined assets are moved transactionally to `_BIN/` with full rollback logging.

##### 6.4 Catalog Hot-Backups & Point-in-Time Rollback
1. Navigate to **⚙️ Settings** → **Database & Operations**.
2. **Create Manual Snapshot**: Enter a descriptive tag (e.g., `pre_sync_backup`) and click **"💾 Run Manual Backup"**.
3. **Restore Snapshot**:
    * Navigate to **⏪ Restore Points**.
    * Select the desired snapshot from the GFS snapshot list.
    * Click **"🔄 Restore Selected Snapshot"**.
    * Enter your 6-digit mobile 2FA TOTP code to confirm the database rollback.

###### 6.5 Mastering the File Vault Explorer Subsystem (v5.1.0)

Navigate to **🏛️ File Vault Explorer (Index 5)** on the left navigation rail.

###### 6.5.1 Sub-Tab 1: Vault Folder Governance &amp; Preservation Status
1. Select a folder node in the directory tree on the left pane.
2. Inspect the **Governance Status Card**:
   * **🔴 RED (`RAW / UNPROMOTED`):** Folder contains master files that require definitive organization.
   * **🟡 YELLOW (`CANONICAL with Unbound Files`):** Folder is canonical, but contains files with unset canonical paths.
   * **🟢 GREEN (`100% Compliant`):** All contained files have `canonical_path = master_path`.
3. Execute required operations using the three action cards:
   * **⭐ Promote to Definitive (CANONICAL):** Marks the directory as permanent archive storage and automatically updates `canonical_path = master_path` for all contained files.
   * **↩️ Reset to Standard Folder (MASTER):** Demotes folder status back to standard unpromoted storage.
   * **➕ Add New Definitive Subfolder:** Creates a new child folder on physical disk and registers the folder in the catalog database.
   * **✏️ Rename Selected Folder:** Physically renames the folder on disk. The engine cascades path changes transactionally across all child files and subfolders in SQLite and appends an audit event to `file_decision_history`.
   * **⚡ Bind Contained Files to Canonical:** Resolves 🟡 Yellow health flags by updating `files.canonical_path = master_path` for all files in that folder.
   * **👉 View Pending Files in Browser:** Switches to Sub-Tab 2 and activates the `🔴 Pending Canonical` filter for the selected folder.
   * **📂 Browse All Files in This Folder:** Switches to Sub-Tab 2 and displays all files in the selected folder.

###### 6.5.2 Sub-Tab 2: File Browser, Filtering &amp; Bulk Movement
1. Select a folder in the folder tree to populate the 6-column table:
   `[ ☑ Selection | Filename | Ext | Size | Type | Status ]`
2. Apply live filters using the top filter ribbon:
   * **Search Box:** Instant substring search across filenames.
   * **Extension Dropdown:** Shows only file extensions present in the active directory.
   * **Category Dropdown:** Dynamic filtering using the SQLite `extension_registry` table (e.g., *Photo*, *Video*, *Music*, *Doc*, *Archives*, *Other*). Selecting a category updates the extension dropdown dynamically.
   * **Status Dropdown:** Filter by preservation state (`All Statuses`, `🔴 Pending Canonical`, or `🟢 Canonical Verified`).
   * **✕ Reset:** Clears all active filters and restores visibility for all rows.
3. Inspect and edit individual files using the right panel:
   * Inspect visual thumbnails for supported images (`JPG`, `PNG`, `WEBP`, `BMP`).
   * Inspect metadata, capture dates, and SHA-256 fixity hashes.
   * Click **📋 Copy SHA-256** to copy the full hash to the system clipboard.
   * Rename a single file using the **File Name** box and click **✏️ Rename File**.
   * Click **🧭 View Full Lineage** to jump directly to Sub-Tab 4 for that file.
4. Execute protected bulk movements:
   * Select files using table checkboxes (or click **Select All** / **Deselect All**). Hidden or filtered rows are protected automatically.
   * Select a target folder using **📁 Pick Target** or type a path relative to the vault root.
   * Click **🚚 Move Checked Files**.
   * If the destination folder is `CANONICAL`, the engine automatically updates `files.canonical_path = new_path`.

###### 6.5.3 Sub-Tab 3: Decision &amp; Move History (Audit Ledger &amp; Rollback)
1. Switch to **📜 Decision &amp; Move History** to view all recorded move, rename, and governance actions.
2. Filter historical records using the filter ribbon:
   * Filter by **Date** (`YYYY-MM-DD`).
   * Filter by **Source Path** or **Target Path** substrings.
   * Filter by **Extension** (`JPG`, `MP4`, `PDF`, etc.).
   * Filter by **Operation Source** (*Vault Explorer Moves*, *Single File Renames*, *Reversals &amp; Rollbacks*, *Canonical Decisions*).
3. Execute 1-click move rollback:
   * Select any row with valid source and destination paths.
   * Click **↩️ Reverse Selected**.
   * The application verifies that the file exists on disk, moves the file back to its previous location, updates the catalog database, and logs a reversal event.
4. Export audit reports:
   * Click **📥 Download Report** to export currently filtered records.
   * Save the report as an Excel workbook (`.xlsx`) or standard CSV document. Output files default to `~/digiArchive_Vault/.archive/sync_reports/`.

###### 6.5.4 Sub-Tab 4: Single-File Multi-Device Lineage Tracing
1. Switch to **🧭 File Lineage**.
2. Supply a 64-character SHA-256 hash using one of these methods:
   * Click **🧭 View Full Lineage** on any file in Sub-Tab 2.
   * Paste a SHA-256 string into the input box and click **🔍 Trace Lineage**.
   * Click **📋 Paste &amp; Trace** to read the clipboard and trace automatically.
   * Double-click any SHA-256 hash in the lineage table.
3. Read the chronological lifecycle timeline across six stages:
   * 🔵 **DISCOVERY:** Device hardware scan occurrence recorded in `asset_inventory`.
   * 🟣 **PROVENANCE:** Device occurrence linked to logical file ID in `file_sources`.
   * 🟡 **INGESTION:** Physical file transfer into vault verified via SHA-256 in `copy_manifest`.
   * 🟢 **VAULT_ACTIVE:** Current active status and canonical path in `files`.
   * 🔷 **DECISION:** Folder moves and file renames logged in `file_decision_history`.
   * 🔴 **QUARANTINE:** File cleanup and quarantine actions logged in `deletion_events`.
4. Click **👉 Locate in File Browser** to navigate back to Sub-Tab 2 with the parent folder selected.
5. Click **📥 Export Lineage** to export the audit timeline to Excel or CSV.


---

#### 7. CLI Maintenance & Dev QR Utilities

##### 7.1 Automated GFS Backups via Cron
Enable automated background hot-backups via **Settings** → **5.4 Automated Catalog Synchronization**, or configure a standard crontab job:
```bash
# Daily GFS Hot-Backup at 02:00 AM
0 2 * * * /usr/local/bin/digiArchive --backup-cron
```

##### 7.2 Generating Dev 2FA QR Codes \[Developer option]
To generate a scannable 2FA enrollment QR image for an existing catalog database without invalidating stored keys:
```bash
python3 scripts/generate_dev_qr.py --db-path ~/digiArchive_Vault/.archive/catalog.db -o dev_qr.png
```

---

#### 8. Troubleshooting & Permission Fixes

##### Resolving `sqlite3.OperationalError: attempt to write a readonly database`
SQLite requires write permissions on both the `.db` file and its containing folder to manage rollback journals (`.db-wal` or `.db-journal`). Run:
```bash
chmod -R 755 ~/digiArchive_Vault
chown -R $USER:$USER ~/digiArchive_Vault
```

##### Resolving `cannot commit - no transaction is active`
Ensure that custom maintenance scripts execute multi-statement SQL via `conn.executescript()` without appending an extraneous `conn.commit()`, as `executescript()` commits transactions automatically.

---

*digiArchive v5.1.0 — Preserving Digital Heritage with Cryptographic Fixity*