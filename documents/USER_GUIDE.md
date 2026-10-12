# 🏛️ digiArchive v5.0.0 — Detailed User Guide

Welcome to the **digiArchive** user guide. This document provides step-by-step instructions for installing, configuring, operating, and maintaining your digital archive and metadata catalog.

---

## 📚 Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Hardware & Software Prerequisites](#2-hardware--software-prerequisites)
3. [Installation & First-Time Launch](#3-installation--first-time-launch)
4. [Two-Factor Authentication (2FA) Mobile Setup](#4-two-factor-authentication-2fa-mobile-setup)
   * [4.1 Why Mobile 2FA is Required](#41-why-mobile-2fa-is-required)
   * [4.2 Step-by-Step Mobile Pairing Walkthrough](#42-step-by-step-mobile-pairing-walkthrough)
   * [4.3 Authenticating Sensitive Administrative Actions](#43-authenticating-sensitive-administrative-actions)
   * [4.4 TOTP Troubleshooting & Clock Drift](#44-totp-troubleshooting--clock-drift)
5. [User Interface Navigation](#5-user-interface-navigation)
6. [Core Workflows](#6-core-workflows)
   * [6.1 Device Onboarding & Hardware Discovery](#61-device-onboarding--hardware-discovery)
   * [6.2 Running Ingestion & Sync Sweeps](#62-running-ingestion--sync-sweeps)
   * [6.3 Duplicate Resolution & Hygiene Sweeps](#63-duplicate-resolution--hygiene-sweeps)
   * [6.4 Catalog Hot-Backups & Point-in-Time Rollback](#64-catalog-hot-backups--point-in-time-rollback)
7. [CLI Maintenance & Cron Automation](#7-cli-maintenance--cron-automation)
8. [Troubleshooting & Permission Fixes](#8-troubleshooting--permission-fixes)

---

## 1. Architecture Overview

digiArchive strictly separates **physical media storage** from **logical database indexing**:

```
+-----------------------------------------------------------------------+
|                       MASTER VAULT (VAULT_ROOT)                       |
|  ├── catalog.db                 <-- SQLite Central Index ('Brain')    |
|  ├── MEDIA_STAGING/             <-- Non-destructive Pull Staging      |
|  ├── _BIN/                      <-- Quarantine Directory              |
|  └── .archive/backups/          <-- GFS Hot-Backup Storage            |
+-----------------------------------------------------------------------+
```

### Physical Occurrences vs. Logical Master Files
* **Physical Occurrence (`asset_inventory`)**: Records a file observed at a specific path on an attached device (e.g. `/sdcard/DCIM/IMG_001.jpg` on `PHONE_A73`).
* **Logical File (`files`)**: Represents unique master file content, uniquely identified by its cryptographic **SHA-256 hash**.
* **Asset Mapping (`asset_map`)**: Links physical occurrences to the logical master file. If three attached devices hold identical media, digiArchive registers three physical occurrences mapped to one logical record, preventing redundant physical duplicate storage.

---

## 2. Hardware & Software Prerequisites

Before launching digiArchive, ensure your environment meets the following specifications:

### 🖥️ Hardware Requirements
* **Host Workstation**: 64-bit x86_64 PC (2.0 GHz dual-core CPU, 2 GB RAM minimum; 4 GB+ RAM recommended). Storage requirements depend on archive media volume.
* **Mobile Smartphone or Tablet**: **Required.** Android or iOS device with a working camera (for scanning setup QR codes) or manual text entry.
* **Cables & Ports**: USB 2.0 or 3.0+ ports with standard data sync cables for connected source devices.

### 📦 Software Requirements
* **Operating System**: Linux x86_64 (Ubuntu 22.04 LTS+, Debian 12+, Fedora 38+, or compatible distribution) running X11 or Wayland.
* **Mobile Authenticator App (RFC 6238 TOTP compliant)**:
  * **Aegis Authenticator** (Android, Open Source — Recommended)
  * **2FAS** (Android / iOS, Open Source)
  * **Google Authenticator** (Android / iOS)
  * **Microsoft Authenticator** (Android / iOS)
  * **Bitwarden** (Integrated TOTP)
* **Optional System Utilities**: `android-tools-adb` for automated Android USB detection (`sudo apt install android-tools-adb`).

---

## 3. Installation & First-Time Launch

### Installing on Linux
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

## 4. Two-Factor Authentication (2FA) Mobile Setup

### 4.1 Why Mobile 2FA is Required
digiArchive enforces an offline security perimeter to protect your digital vault against accidental deletions, unauthorized database rollbacks, and catalog overwrites. 

All sensitive administrative actions require a **6-digit Time-Based One-Time Password (TOTP)** generated on your smartphone. Because TOTP runs completely offline using mathematical cryptography (RFC 6238), neither your workstation nor your phone requires an active internet connection.

### 4.2 Step-by-Step Mobile Pairing Walkthrough

When you launch digiArchive with a newly initialized database or access the security vault for the first time:

1. **Trigger Setup**: The application automatically displays the **2FA Security Setup Wizard** dialog.
2. **Open Authenticator App on Mobile**:
   * Open your chosen mobile authenticator app (e.g. Aegis, 2FAS, Google Authenticator).
   * Tap the **Add Account / `+`** button.
3. **Scan QR Code or Enter Secret**:
   * **Option A (Camera Scan)**: Select **Scan QR Code** in the app and point your phone camera at the QR code displayed on the digiArchive screen.
   * **Option B (Manual Entry)**: If your camera is unavailable, select **Enter Key Manually**, set the account name to `digiArchive (Vault)`, and copy the alphanumeric Base32 secret string displayed below the QR code.
4. **Save Account**: Confirm and save the entry in your mobile authenticator. The app will begin generating a new 6-digit verification code every 30 seconds.
5. **Verify Pairing**:
   * Enter the current 6-digit code shown in your phone app into the **Verification Code** input box in digiArchive.
   * Click **"Confirm & Lock Vault"**.
6. **Store Recovery Secret**:
   * Once validated, digiArchive displays your encrypted backup recovery string.
   * Record this string in a secure offline location (e.g. password manager or paper record) to recover access if your mobile device is replaced.

---

### 4.3 Authenticating Sensitive Administrative Actions

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
3. Enter the current 6-digit code for `digiArchive` and click **"Authenticate"**.

---

### 4.4 TOTP Troubleshooting & Clock Drift

* **"Invalid One-Time Password"**: 
  * TOTP calculates codes based on the current Unix timestamp in 30-second intervals.
  * Ensure your workstation system clock and smartphone clock are synchronized to network time (NTP). A system clock discrepancy of more than 60 seconds will cause verification to fail.
  * On Linux, synchronize your clock using:
    ```bash
    sudo timedatectl set-ntp on
    ```
* **Lost Phone / Replacement**:
  * If you migrate to a new phone, enter your saved Base32 emergency recovery string into your new authenticator app to restore code generation immediately.

---

## 5. User Interface Navigation

digiArchive features a modern Slate/Zinc dashboard with a left-hand navigation rail providing quick access to 6 specialized views:

| View Icon & Name         | Purpose                                                                                   |
|:-------------------------|:------------------------------------------------------------------------------------------|
| **🗂️ Welcome Dashboard** | High-level system health, master repository metrics, and quick action shortcuts.          |
| **📱 Devices & Sources** | Registered device profiles, 2x2 interactive device category cards, and hardware scanning. |
| **🧹 Device Hygiene**    | Media cleanup tools, empty folder sweeps, thumbnail pruning, and quarantine management.   |
| **⚡ Ingestion Engine**  | Non-destructive pull ingestion from attached devices into media staging.                  |
| **⏪ Restore Points**    | Point-in-time recovery, GFS snapshot inspection, and catalog restoration.                 |
| **⚙️ Settings**          | Master repository paths, catalog DB settings, CLI maintenance, license terms, and logs.   |

---

## 6. Core Workflows

### 6.1 Device Onboarding & Hardware Discovery
1. Connect your source device (Android smartphone, tablet, USB storage drive, or external HDD) via USB.
2. Navigate to **📱 Devices & Sources**.
3. Click **"🔄 Refresh & Check Connected Hardware"**.
4. If an unregistered device is detected, the **Hardware Discovery Dialog** appears:
   * Select whether to associate the hardware with an existing profile or onboard it as a new device.
   * Provide an intuitive device label (e.g. `Samsung Galaxy Tab S8`, `SanDisk 1TB SSD`).

### 6.2 Running Ingestion & Sync Sweeps
1. Navigate to **⚡ Ingestion Engine**.
2. Select your target **Source Device** from the dropdown menu.
3. Choose the directories to ingest (e.g. `/sdcard/DCIM`, `/sdcard/Pictures`).
4. Click **"Start Non-Destructive Sync"**.
5. The engine executes fixity checks:
   * SHA-256 checksums are calculated for all source files.
   * New unique files are staged in `MEDIA_STAGING/`.
   * Occurrences are recorded in `asset_inventory` and linked to master files in `asset_map`.
   * Source devices are accessed in read-only mode and are never modified.

### 6.3 Duplicate Resolution & Hygiene Sweeps
1. Navigate to **🧹 Device Hygiene**.
2. Select **"Scan for Duplicates"**.
3. The scanner displays duplicate groups where multiple devices hold identical SHA-256 assets.
4. Choose an action policy (`KEEP_ONE`, `KEEP_ALL`, or `QUARANTINE`) and apply. Quarantined assets are moved transactionally to `_BIN/` with full rollback logging.

### 6.4 Catalog Hot-Backups & Point-in-Time Rollback
1. Navigate to **⚙️ Settings** → **Database & Operations**.
2. **Create Manual Snapshot**: Enter a descriptive tag (e.g. `pre_sync_backup`) and click **"💾 Run Manual Backup"**.
3. **Restore Snapshot**:
   * Navigate to **⏪ Restore Points**.
   * Select the desired snapshot from the GFS snapshot list.
   * Click **"🔄 Restore Selected Snapshot"**.
   * Enter your 6-digit mobile 2FA TOTP code to confirm the database rollback.

---

## 7. CLI Maintenance & Cron Automation

### Automated GFS Backups via Cron
Enable automated background hot-backups via **Settings** → **5.4 Automated Catalog Synchronization**, or configure a standard crontab job:

```bash
# Daily GFS Hot-Backup at 02:00 AM
0 2 * * * /usr/local/bin/digiArchive --backup-cron
```

---

## 8. Troubleshooting & Permission Fixes

### Resolving `sqlite3.OperationalError: attempt to write a readonly database`
SQLite requires write permissions on both the `.db` file and its containing folder to manage rollback journals (`.db-wal` or `.db-journal`). Run:

```bash
chmod -R 755 ~/digiArchive_Vault
chown -R $USER:$USER ~/digiArchive_Vault
```

### Resolving `cannot commit - no transaction is active`
Ensure that custom maintenance scripts execute multi-statement SQL via `conn.executescript()` without appending an extraneous `conn.commit()`, as `executescript()` commits transactions automatically.

---

*digiArchive v5.0.0 — Preserving Digital Heritage with Cryptographic Fixity*