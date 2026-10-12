# 📋 digiArchive v5.0.0 — Stable Release Notes

**Release Version:** `v5.0.0` (First Official Stable Release / General Availability)  
**Release Date:** October 2026  
**Build Target:** Linux x86_64  
**Binary Executable:** `digiArchive-linux-x86_64.bin`  
**Git Tag:** `v5.0.0`  

---

## 🌟 Executive Summary

**digiArchive v5.0.0** marks the first official, production-ready stable release of the Digital Asset & Metadata Manager. Built with Python 3.12, PyQt6, SQLite, and compiled via Nuitka into a zero-dependency standalone Linux binary, v5.0.0 delivers an enterprise-grade, PII-safe digital archive solution. 

This milestone delivers complete architectural decoupling of physical storage occurrences from deduplicated logical identities, a modernized and theme-ratified graphical interface, hot Grandfather-Father-Son (GFS) database snapshotting, dynamic 2FA onboarding, and verified 100% test coverage across all regression suites.

---

## 🚀 Key Features & Highlights in v5.0.0

### 1. Decoupled & Coupled Database Engine
* **Flexible Architecture:** Supports storing `catalog.db` either coupled within the vault metadata directory (`<vault_root>/.archive/catalog.db`) or decoupled in an arbitrary custom location.
* **Automatic Subpath Normalization:** Detects path mismatches and provides guided options to copy, initialize, or operate in decoupled mode without risking vault integrity.
* **Pure Physical vs. Logical Separation:**
  * `asset_inventory`: Tracks physical device occurrences, source paths, and file metadata non-destructively.
  * `files`: Tracks globally unique logical file entities indexed by SHA-256 fixity hashes.
  * `asset_map`: Relational bridge connecting physical occurrences to canonical master records.

### 2. Modular Schema Loader Delegation (DRY Architecture)
* **Zero Embedded SQL:** Completely eliminated 100+ lines of raw SQL DDL strings from UI presentation logic.
* **Delegation to `load_schema.py`:** Fresh catalog initialization now invokes `apply_schema_to_db` from `src/tools/load_schema.py`, ensuring automatic multi-path schema discovery, legacy table filtering, and idempotent execution (`IF NOT EXISTS`).
* **Safe Subprocess Fallback:** Dual-path execution falling back to `sys.executable` CLI runner if module imports are unavailable.

### 3. Comprehensive Settings & Operations Overhaul
Reorganized the Settings panel into six structured, dedicated sub-tabs:
* **Sub-Tab 0 (Software License & Open Source Terms):** Displays clean MIT license terms, copyright notice, developer contact, and issue tracker via `license.py` with native link launching.
* **Sub-Tab 1 (MASTER Vault & Repository Configuration):** Unified configuration for Vault Name, Root Path, and Catalog DB with atomic lock enforcement (`🔒 Confirm & Lock All`).
* **Sub-Tab 2 (Database Operations & Maintenance Scripts):** Dedicated interface for running schema extraction, integrity audits, and custom arguments.
* **Sub-Tab 3 (Process Execution & Diagnostics Log):** Real-time streaming log capturing stdout and stderr from background operations.
* **Sub-Tab 4 (Automated Catalog Synchronization & Cron Scheduling):** OS crontab integration for scheduled background catalog synchronization.
* **Sub-Tab 5 (GFS Database Snapshot Catalog):** Interactive table and management controls for automated database backup snapshots.

### 4. Full Desktop Theme Ratification (Light & Dark Parity)
* **Complete Visual Parity:** Eliminated local inline stylesheet overrides that previously caused unreadable contrast when switching to the **Zinc Alabaster (Light)** theme.
* **Semantic Selectors:** Converted custom frames and card components to semantic `setObjectName` selectors (`#info_callout`, `#license_card`, `#props_frame`), unified in `styles.py`.

### 5. Hot GFS Snapshot Engine & 2FA Safeguards
* **Non-Blocking Hot Backups:** Utilizes native SQLite page-level backup APIs (`db_backup.py`) to take snapshots without lock contention or application downtime.
* **Retention Scheduling:** Automated Grandfather-Father-Son rotation (Daily: 7 days, Weekly: 4 weeks, Monthly: 12 months, Manual: 30 days).
* **Two-Factor Authentication (2FA):** Mandatory TOTP verification (`SecureRestoreDialog`) before permitting database restoration or active catalog replacement. Includes dynamic Base32 secret generation and native QR code enrollment (`Initial2FASetupDialog`).

### 6. UI Mnemonic Escaping & Dialog Rich-Text Polish
* **Mnemonic Normalisation:** Escaped reserved Qt ampersand characters (`&&`) across tab labels, group boxes, and buttons (`Vault && Repository`, `Database && Operations`) to resolve character underlines.
* **Rich-Text Dialogs:** Standardised all `QMessageBox` popups with explicit `<html>...<br>` tags to prevent raw formatting tags from displaying in error/confirmation prompts.

### 7. Standalone Linux Packaging & Automated Installer Suite
* **Zero Runtime Prerequisites:** Standalone executable compiled via Nuitka (`digiArchive-linux-x86_64.bin`) bundling Python 3.12, PyQt6, and core dependencies.
* **Installer Automation:**
  * `installers/install-digiarchive.sh`: One-step installation to `/usr/local/bin` with desktop launcher and application menu integration.
  * `installers/uninstall-digiarchive.sh`: Complete, clean uninstallation script.

---

## 🧪 Quality Assurance & Verification

* **Automated Regression Suite:** 38/38 passing test suites covering:
  * Database queries, foreign key enforcement, and schema idempotency.
  * Deduplication fixity and SHA-256 hash collision resilience.
  * Device scanning and hygiene sweeps.
  * TDD hardened safeguards and tamper protection.
* **Dual-Privacy Reporting:** Verifiably enforces separation between internal forensic logs (`LOCAL_FULL_DO_NOT_SHARE`) and sanitized shareable summaries (`SAFE_SUMMARY_SHAREABLE`).

---

## 📦 Release Artifacts

| Artifact                              | Type              | Description                                   |
|:--------------------------------------|:------------------|:----------------------------------------------|
| `digiArchive-linux-x86_64.bin`        | Binary Executable | Standalone compiled executable (Linux x86_64) |
| `installers/install-digiarchive.sh`   | Shell Script      | Automated system installer                    |
| `installers/uninstall-digiarchive.sh` | Shell Script      | Automated uninstaller                         |
| `README.md`                           | Documentation     | Project overview and quick-start guide        |
| `USER_GUIDE.md`                       | Documentation     | End-user operational documentation            |
| `CHANGELOG.md`                        | Documentation     | Comprehensive version history                 |
| `RELEASE_NOTES_v5.0.0.md`             | Documentation     | Official v5.0.0 release notes                 |

---

*digiArchive Development Team — October 2026*
