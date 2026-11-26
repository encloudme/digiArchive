# 📋 digiArchive v5.0.5 — Release Notes
### Ingestion Reporting & Vault Explorer Integration

**Release Version:** `v5.0.5`  
**Release Date:** 22 November 2026  
**Build Target:** Linux x86_64  
**Binary Executable:** `digiArchive-linux-x86_64.bin`  
**Release Theme:** Ingestion Reporting & Vault Explorer Integration  
**Git Tag:** `v5.0.5`  

---

## 🌟 Executive Summary

**digiArchive v5.0.5** delivers milestone parity for operational reporting, introduces an interactive File Vault Explorer, and hardens application responsiveness across multi-gigabyte ingestion sessions.

This release integrates native multi-sheet Excel (`.xlsx`) and CSV audit reporting directly into the Ingestion & Sync workflow, routes audit archives to `.archive/sync_reports/`, and introduces a persistent collapsible navigation rail (240px ↔ 68px). Additionally, v5.0.5 eliminates GUI thread freezes during Restore Points navigation, enforces 64-bit Qt signal typing (`qint64`), expands transfer buffers to 4 MB, and adds high-contrast accessibility scrollbars across all Light and Dark palettes.

---

## 🚀 Key Improvements & Highlights in v5.0.5

### 1. Operational Ingestion Reporting Parity (Milestone v5.0.5)
* **Multi-Tab Excel Generation:** Pure `openpyxl` engine exporting ingestion session manifests directly to formatted `.xlsx` workbooks.
* **Three Dedicated Audit Worksheets:**
  * **`Session Summary`:** Captures Session ID, Device ID, Source Scope, Target Vault, Transfer Counts, Total Bytes, and Duration.
  * **`Transferred Files (NEW)`:** Records Relative Path, File Size (Bytes & KB), Verified SHA-256 Fixity Hash, MIME Type, and Destination Path.
  * **`Duplicate Occurrences`:** Tracks identical SHA-256 matches mapped to pre-existing catalog assets without physical re-transfer.
* **Resilient CSV Fallback:** Automatically switches to streaming standard CSV export if `openpyxl` is not detected in the environment.
* **Streamlined UI Integration:** Added **📊 Export Excel Report** action button on the ingestion completion ribbon, automatically routing files to `<vault_root>/.archive/sync_reports/` and opening the system file manager.

### 2. Interactive File Vault Explorer (FR-32)
* **Master Vault Directory Navigation:** Implemented dedicated File Vault Explorer tab (`src/vault_explorer_ui.py`) using `QFileSystemModel` to browse active directory hierarchies in the `MASTER` repository.
* **Dynamic Split-Pane Metadata Inspector:** Displays canonical storage paths, human-readable file sizes, capture timestamps, media classification, and SHA-256 fixity hashes for cataloged media.
* **Collapsible Navigation Rail:** Replaced top navigation with a space-saving left-side rail supporting instant collapse and expansion (240px expanded ↔ 68px compact).

### 3. Concurrency Hardening & UI Responsiveness (FR-35, FR-36, FR-37, FR-39)
* **Asynchronous Ingestion Worker (`SyncExecutionWorker`):** Moved staging, file copying, and database commits off the Qt main thread into a dedicated worker, eliminating desktop "Not Responding" conditions.
* **64-Bit Integer Signal Typing (`qint64`):** Fixed PySide6 signal overflow crashes on files larger than 2.14 GB by binding byte-count signals to 64-bit integers.
* **High-Throughput 4 MB I/O Buffer:** Expanded streaming copy buffer from 64 KB to 4 MB (`4,194,304` bytes), reducing system call overhead on large media assets.
* **Database Busy Timeout:** Enforced `PRAGMA busy_timeout = 60000;` on all SQLite connections to eliminate `SQLITE_BUSY` lockups during background GFS backup cron jobs.
* **Restore Points Freeze Fix:** Eliminated thread destruction race conditions and event loop re-entrancy in `restore_ui.py`, switching table headers to `Interactive` resize mode to eliminate UI thread latency.

### 4. UI Architecture & Accessibility Polish
* **Decoupled Theme Architecture:** Refactored styling into `src/app_styles.py` with dynamic `register_theme()` hooks for scalable palette management.
* **High-Contrast Dark Scrollbars:** Styled dark theme scrollbar thumbs with slate grey handles (`#475569`), distinct borders (`#94a3b8`), and sky-blue hover highlights (`#0284c7`).
* **Dashboard Contrast Rectification:** Fixed low-contrast text in Welcome Dashboard storage gauges, action card descriptions, and sidebar headers across all 6 Light and Dark themes.

---

## 🧪 Quality Assurance & Test Verification

* **Automated Regression Suite:** **38/38 tests passing cleanly** via `tests_suite/run_tests.py -s "*" -eh -xs`.
* **Verified Test Areas:**
  * Catalog schema invariants and composite unique constraints (`catalog_schema_v5.0.2`).
  * Ingestion fixity, dual-stage scan/sync, and multi-sheet reporting generation.
  * Device hygiene sweeps, survivor protection, and duplicate segregation.
  * Vault switching, credential verification, and thread-safe database connection recycling.

---

## 📦 Release Artifacts

| Artifact | Type | Description |
| :--- | :--- | :--- |
| `digiArchive-linux-x86_64.bin` | Standalone Executable | Compiled standalone Linux binary (Nuitka onefile) |
| `digiArchive-linux-x86_64.bin.sha256` | Checksum File | SHA-256 fixity checksum for binary distribution |
| `../../installers/install-digiarchive.sh` | Shell Script | Automated desktop installer with dependency checks |
| `../../installers/uninstall-digiarchive.sh` | Shell Script | System uninstaller and desktop entry cleaner |
| `releases/digiArchive-build-release.sh` | Build Script | Standalone distribution build automation script |
| `../../CHANGELOG.md` | Documentation | Chronological release log with v5.0.5 and v5.0.4 entries |
| `RELEASE_NOTES_v5.0.5.md` | Documentation | Official v5.0.5 release documentation |

---

*digiArchive Development Team — November 2026*