# digiArch!ve 🗄️

> **Digital Archive & Metadata Manager** (v5.0 (Beta))  
> *Authoritative Multi-Device Ingestion, Non-Destructive Storage Hygiene & Cryptographic Fixity Archiving.*

---

## 🏛️ Overview

**digiArch!ve** is a high-performance desktop application built with Python 3, PyQt6, and SQLite. It provides a robust, privacy-first platform for cataloging, maintaining, and synchronizing media assets across heterogeneous physical hardware—including Android tablets/phones (via ADB), USB flash drives, external HDDs, and local PC workstations—without modifying original source data during evaluation.

Designed around a non-destructive read-to-catalog pipeline, **digiArch!ve** maintains a strict architectural separation between **Physical Occurrences** (where files are observed on hardware) and **Logical Master Files** (unique content identified by SHA-256 checksums).

---

## ✨ Key Features & Archival Guarantees

### 📱 1. Hardware Discovery & Device Profiling
* **Multimodal Hardware Probing:** Automatically detects connected Android devices via `adb` and external storage partitions via `lsblk` / `psutil`.
* **1:N Signature Binding:** Links hardware profiles (manufacturer, model, OS version, serials, ADB IDs, mount points) to master catalog device records.
* **Interactive Category Cards:** Real-time visual status cards showing live connection glows for Android Tablets, Workstations, Smartphones, and USB drives.

### ⚡ 2. Two-Pass Ingestion & Delta Engine
* **Non-Destructive Metadata Scanning:** Pass 1 indexes file metadata (path, size, modification time) without whole-file hashing to keep storage access fast.
* **Content Delta Classification:** Pass 2 computes SHA-256 hashes on-demand to categorize occurrences as `NEW`, `KNOWN`, `CHANGED`, or `DUPLICATE_EXACT`.
* **Exact Duplicate Bypass:** `DUPLICATE_EXACT` assets skip redundant physical network/USB transfer phases while registering physical occurrence provenance in the catalog.
* **End-to-End Fixity Verification:** Enforces cryptographic SHA-256 verification across Source, Staging, and MASTER target storage zones before confirming transactional commits.

### 🧹 3. Device Hygiene & Quarantine (`_BIN`)
* **Automated Scrap Detection:** Identifies thumbnail caches (`.thumbnails`, `.thumb`), non-system temporary logs/caches (`.tmp`, `.log`, `.cache`), and 0-byte empty files.
* **Sentinel Protection:** Enforces strict exclusion rules to preserve `.nomedia` sentinel files.
* **Safe Quarantine Pipeline:** Copies target files to a local `_BIN` quarantine folder, verifies file size and SHA-256 fixity, and only deletes source files after verified backup.
* **Intra-Device Duplicate Grouping:** Clusters identical size files and batch-hashes ADB candidates to isolate genuine duplicate user files.

### ⏪ 4. Restore Points & Rollback Recovery
* **Quarantine Rollback:** Recovers quarantined files from `_BIN` back to their original device paths with fixity re-verification.
* **Shielded Admin Lock:** Enforces offline administrator authentication (SHA-256 Password + RFC 6238 TOTP 2FA) to unlock database rollback operations.
* **Master Database Rollback:** Restores catalog database snapshots while safely severing active connection handles and taking automatic pre-rollback safety copies.

### ⚙️ 5. GFS Hot-Backups & Database Integrity
* **Grandfather-Father-Son (GFS) Backups:** Native SQLite page-copier engine running online, non-blocking hot-backups mapped into Daily (7-day), Weekly (4-week), Monthly (12-month), and Manual snapshot tiers.
* **Sticky-Bit Protection:** Toggles directory sticky-bits (`+t` / `-t`) and SQLite journal modes (`WAL` / `DELETE`) to prevent accidental deletion or corruption of catalog files.
* **PII-Safe Auditing & Schema Tools:** Built-in tools for extracting SQLite schema structures and running read-only integrity audits without exporting user filenames or paths.

### 🎨 6. Modern Zinc / Obsidian Theme Suite
* **6 WCAG AA/AAA Compliant Themes:** *Slate Obsidian*, *Zinc Alabaster*, *Aero Sapphire*, *Carbon Emerald*, *Aero Magenta*, and *Neon Obsidian*.
* **Custom 3D Donut Visualizer:** Custom-painted circular progress ring rendering real-time scanning, hashing, and transfer throughput.

---

## 📂 Repository Layout

```
digital_archive/
├── src/
│   ├── digiArchive.py              # Main GUI application entry point
│   ├── config.py                   # Centralized settings & Path.home() resolution
│   ├── db.py                       # Thread-safe SQLite connection pool & registry
│   ├── device_engine.py            # Hardware probing (ADB & block storage)
│   ├── scanner.py                  # Two-pass non-destructive filesystem scanner
│   ├── delta_engine.py            # Physical occurrence vs. logical file evaluator
│   ├── sync_engine.py             # Transactional staging, promotion & fixity engine
│   ├── cleaner.py                 # Device hygiene & quarantine worker
│   ├── welcome_ui.py              # Dashboard & KPI metrics UI tab
│   ├── sync_ui.py                 # Ingestion & Sync UI tab
│   ├── cleaner_ui.py              # Device Hygiene UI tab
│   ├── restore_ui.py              # Quarantine rollback & session manifests UI tab
│   ├── styles.py                  # Zinc theme palette collection
│   ├── security.py                # Cryptographic password & TOTP 2FA module
│   └── tools/
│       ├── db_backup.py            # GFS online hot-backup engine
│       ├── schema_extractor.py     # PII-safe SQLite schema extractor
│       └── catalog_integrity_audit.py # Read-only catalog integrity audit tool
├── config/
│   └── digital-archive.desktop     # FreeDesktop menu launcher definition
├── assets/                         # High-res icon assets (digiArchive.png)
├── queryDB_files/                  # SQL query repository & index optimization tools
└── tests_suite/                    # Automated regression and integration test suite
```

---

## 🚀 Quick Start & Installation

### Prerequisites
* **Linux (Ubuntu / Debian recommended)**, macOS, or Windows
* **Python 3.10+**
* **PyQt6**, **psutil**, **openpyxl**
* **ADB CLI tools** (optional, required for Android tablet/phone scanning)

### 1. Clone & Setup Environment
```bash
# Clone repository
git clone git@github.com:your-username/digital_archive.git
cd digital_archive

# Create and activate Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install PyQt6 openpyxl psutil
```

### 2. Launch the Application
```bash
python3 src/digiArchive.py
```

---

## 🖥️ GNOME Desktop Launcher Setup

To pin **digiArch!ve** to your GNOME application grid and menu bar:

1. Copy the application icon to your user icons directory:
   ```bash
   mkdir -p ~/.local/share/icons/hicolor/256x256/apps/
   cp src/assets/icons/digiArchive.png ~/.local/share/icons/hicolor/256x256/apps/digiArchive.png
   ```

2. Install the desktop launcher file:
   ```bash
   cp config/digital-archive.desktop ~/.local/share/applications/
   ```

3. Verify GNOME launcher execution:
   ```bash
   gtk-launch digital-archive.desktop
   ```

---

## ⚙️ Configuration Defaults

**digiArch!ve** stores application settings in `~/.config/digital_archive/config.json`. Default directory anchors automatically resolve dynamically relative to your user home directory (`Path.home()`):

| Setting Key        | Default Resolved Path                        | Purpose                                         |
|--------------------|----------------------------------------------|-------------------------------------------------|
| `db_path`          | `~/DigitalArchive_Vault/.archive/catalog.db` | Active SQLite Master Catalog Index              |
| `master_repo_root` | `~/DigitalArchive_Vault`                     | Physical Vault root for canonical media storage |
| `bin_root`         | `~/DigitalArchive_Vault/_BIN`                | Quarantine folder for deleted hygiene files     |
| `staging_root`     | `~/DigitalArchive_Vault/MEDIA_STAGING`       | Temporary staging area for active sync sessions |
| `output_dir`       | `~/DigitalArchive_Vault/.archive/reports`    | Default destination for schema & audit reports  |

---

## 📜 License & Compliance

This repository is maintained for digital archiving, media cataloging, and personal data preservation. Audit utilities (`schema_extractor.py` and `catalog_integrity_audit.py`) operate strictly in **PII-Safe mode**, exporting metadata schemas, controlled vocabulary enums, and row counts without outputting user file paths, filenames, or content hashes.