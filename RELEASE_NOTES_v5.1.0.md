# 📋 digiArchive v5.1.0 — Release Notes
### Canonical Vault Governance, Multi-Device Lineage & Audit Rollback

**Release Version:** `v5.1.0`  
**Release Date:** 26 November 2026  
**Build Target:** Linux x86_64  
**Binary Executable:** `digiArchive-linux-x86_64.bin`  
**Release Theme:** Milestone v5.1.0 (FR-32) — Canonical Organization & Vault Governance Engine  
**Git Tag:** `v5.1.0`  

---

## 🌟 Executive Summary

**digiArchive v5.1.0** delivers full milestone completion for **FR-32 (Canonical Vault Governance & Organization Engine)**. This release transitions the master repository from a static file viewer into an active, audit-backed digital archive management system.

Instead of rigid programmatic folder formulas, v5.1.0 implements a **user-centric governance architecture**. Users can classify folders as definitive (`CANONICAL`), create sub-hierarchies, rename directories on disk with automatic database cascade, and bind files to canonical preservation contracts. 

Additionally, v5.1.0 introduces **Sub-Tab 3 (Decision & Move History)** with 1-click transactional rollback, **Sub-Tab 4 (File Lineage)** with a 6-table unified SQL lifecycle trace by SHA-256, real-time three-state folder health flags (🔴 Red / 🟡 Yellow / 🟢 Green), dynamic multi-criteria filter ribbons synchronized with the SQLite `extension_registry`, and complete multi-format audit report export to Excel (`.xlsx`) and CSV.

All 38 automated test suites pass with zero regressions (38/38 PASS).

---

## 🚀 Key Improvements & Highlights in v5.1.0

### 1. Interactive Vault Governance & Directory Operations (FR-32 Phase A)
* **Structured Governance Action Cards:** Reorganized Sub-Tab 1 operations into three logical cards:
  * **Archive Classification & Policy:** Promote folders to `CANONICAL` or demote to standard `MASTER`.
  * **Directory Structure & Hierarchy:** Add definitive subfolders or rename directories with cascade catalog path updates.
  * **File Compliance & Navigation:** Resolve unpromoted files, update canonical contracts, and jump to the file browser.
* **Database Cascade on Directory Rename:** Renaming a directory on disk updates all child file paths (`master_path` and `canonical_path`) and child folder records transactionally in SQLite, logging the action in `file_decision_history`.
* **Signal Storm Elimination:** Wrapped tree clears and population in `blockSignals(True)` and `blockSignals(False)` to eliminate Qt recursive event starvation and processing cursor lockups.
* **Auto-Clear Move Target:** Automatically clears the destination path input field after successful bulk moves to prevent unintended repeated moves.

### 2. File Browser & Dynamic Filter Ribbon (FR-32 Phase A)
* **6th Column 'Ext':** Added dedicated file extension column with uppercase pill badge rendering to `tbl_files`.
* **Dynamic Category & Extension Filtering:** Connected filter dropdowns to the authoritative SQLite `extension_registry` table. Selecting a category (e.g., *Photo*, *Video*, *Audio*, *Document*, *Archive*, *Other*) updates valid extensions dynamically.
* **Canonical Status Filter:** Filter folder contents by compliance state: `All Statuses`, `🔴 Pending Canonical`, and `🟢 Canonical Verified`.
* **Pre-Flight Collision Guard:** `execute_bulk_move()` checks target paths before moving files, skipping colliding files with descriptive user alerts.

### 3. Decision Audit Ledger & 1-Click Rollback (FR-32 Phase B)
* **Sub-Tab 3 (Decision & Move History):** Displays complete audit trail querying `file_decision_history` with timestamps, previous paths, target paths, operation sources, and execution status.
* **1-Click Transactional Rollback (`reverse_selected_decision`):** Reverses moves, renames, and bulk operations. Moves files back on disk and updates catalog database paths in an atomic transaction.
* **Multi-Criteria Filter Ribbon:** Filter history entries by Decision Date (`YYYY-MM-DD`), Source Path substring, Target Path substring, File Extension, and Operation Source.
* **Filtered Audit Report Export:** Export filtered history records directly to formatted Excel (`.xlsx`) with openpyxl or streaming UTF-8 CSV saved to `.archive/sync_reports/`.

### 4. Multi-Device SHA-256 Lineage Subsystem (FR-32 Phase C)
* **Unified 6-Table Lifecycle Query:** Implemented a Common Table Expression (CTE) query uniting `asset_inventory`, `file_sources`, `copy_manifest`, `files`, `file_decision_history`, and `deletion_events`.
* **Immutable Fixity Tracking:** Traces any 64-character SHA-256 hash across all lifecycle stages:
  * 🔵 `DISCOVERY` (Scanned on Device)
  * 🟣 `PROVENANCE` (Linked to Logical File ID)
  * 🟡 `INGESTION` (Copied to Vault with Fixity Verification)
  * 🟢 `VAULT_ACTIVE` (Active Master Catalog State)
  * 🔷 `DECISION` (Move / Rename Governance Actions)
  * 🔴 `QUARANTINE` (Moved to `_BIN`)
* **Clipboard Integration:** Added **📋 Paste & Trace** button, live 64-char clipboard detection, and double-click cell copy.
* **Bi-Directional Navigation:** 1-click jump from File Browser to Lineage, and 1-click jump from Lineage back to File Browser.
* **Lineage Report Export:** Export complete file lifecycle timeline to styled Excel or CSV reports.

### 5. Health Flags & Canonical Binding (FR-32 Phase D)
* **Three-State Visual Health Badge:**
  * 🔴 **RED:** Folder is unpromoted `MASTER` with files pending canonical organization.
  * 🟡 **YELLOW:** Folder is `CANONICAL`, but contains files with unset or mismatched `canonical_path`.
  * 🟢 **GREEN:** 100% compliant; all files bound to definitive canonical paths.
* **Interactive Canonical Binding:** Added **⚡ Bind Contained Files to Canonical** to update `canonical_path = master_path` for all files in definitive folders.
* **Automatic Binding on Move:** Moving files into definitive canonical folders automatically updates `files.canonical_path`.

### 6. Architecture, Startup & Theme Polish
* **Centralized Theme Engine (`app_styles.py`):** Removed local inline overrides. All cards, buttons, titles, and ribbons adapt cleanly across all 6 themes (*Slate Obsidian*, *Zinc Alabaster*, *Aero Sapphire*, *Carbon Emerald*, *Aero Magenta*, *Neon Obsidian*).
* **Startup Catch-Up Notification Wire:** Fixed missed GFS backup catch-up runner to notify Settings and Welcome screens immediately on launch.
* **Fixed Fatal `TypeError` in Navigation:** Fixed 3-argument `hasattr()` bug in `digiArchive.py` when opening Restore Points.
* **Automated Regression Suite:** 38/38 unit and integration tests passing.

---

## 📊 Verification & Test Results

| Test Category | Suite File | Total Tests | Pass | Fail |
| :--- | :--- | :--- | :--- | :--- |
| **Fixity & Ingestion Safety** | `tests_suite/test_sync_fixity.py` | 10 | 10 | 0 |
| **Database Operations & Concurrency** | `tests_suite/test_database_queries.py` | 8 | 8 | 0 |
| **Catalog Integrity & Foreign Keys** | `tests_suite/t_catalog_integrity_audit.py` | 15 | 15 | 0 |
| **Hygiene & Quarantine Sweeps** | `tests_suite/test_cleaner_sweeps.py` | 5 | 5 | 0 |
| **Total Test Execution** | `python3 run_tests.py -s "*"` | **38** | **38** | **0** |

---

## 📦 Upgrading to v5.1.0

### From Source
```bash
git checkout main
git pull origin main
git checkout v5.1.0

# Verify test suite
python3 run_tests.py -s "*"

# Launch digiArchive
python3 -m src.digiArchive
```