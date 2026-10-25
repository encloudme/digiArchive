### 📋 digiArchive v5.0.1 — Maintenance, Vault Security & Startup Release Notes
**Release Version:** v5.0.1  
**Release Date:** 25 October 2026  
**Build Target:** Linux x86_64  
**Binary Executable:** `digiArchive-linux-x86_64.bin`  
**Git Tag:** `v5.0.1`  

---

#### 🌟 Executive Summary
**digiArchive v5.0.1** is a comprehensive maintenance, vault security, and feature refinement release building directly upon the v5.0.0 production baseline.

This release introduces the **FR-18 Vault Security Architecture** (storing administrative credentials, Base32 TOTP secrets, Vault Name, and immutable DB UUIDs directly inside the SQLite `vault_security` database table), an idempotent startup auto-migration pipeline, a CLI 2FA QR code generator (`scripts/generate_dev_qr.py`), and a dual-mode video splash screen (`LogoSplashDialog` and `LogoSplashWidget`). Furthermore, this release features a hardened Nuitka compiler release builder (`build_release_damm.sh`) with strict memory defenses, achieving 100% pass rates across 38 automated pre-commit regression test suites.

---

#### 🚀 Key Improvements & Highlights in v5.0.1

##### 1. FR-18 Vault Security Architecture (Step 1)
* **Embedded Security Table:** Integrated `vault_security` into SQLite schema (`database/schema.sql` v3.1) housing `db_uuid` (immutable UUID v4), `admin_hash`, `totp_secret`, and `vault_name`.
* **Schema Safeguard Triggers:** Enforced SQLite triggers preventing modification or deletion of the immutable `db_uuid` row once inserted.
* **Idempotent Auto-Migration Hook:** Wired startup auto-migration into `digiArchive.py` that automatically ports legacy credentials (`admin_hash`, `totp_secret`) from `config.json` into `catalog.db` (`vault_security` table) and prunes sensitive keys from disk config files.
* **Dynamic Setup & Onboarding:** Enhanced `InitialSetupDialog` in `welcome_ui.py` supporting live Vault Name and DB Name customization with real-time 2FA QR code re-rendering and authenticator key segregation.

##### 2. Developer & CLI Utility Suite
* **Dev 2FA QR Generator (`scripts/generate_dev_qr.py`):** Standalone CLI utility generating scannable 2FA QR PNG images directly from existing `catalog.db` TOTP secrets via `generate_qr_from_existing_secret()`, preventing token invalidation or authenticator desynchronization.

##### 3. Startup Video Splash Pipeline
* **Brand Launch Experience:** Seamlessly plays `assets/welcome/digiArchive_launch.mp4` via PySide6 `QMediaPlayer`, `QAudioOutput`, and `QVideoWidget` across all application launches.
* **Dual-Mode Architecture:** Supports both standalone modal dialog (`LogoSplashDialog`) and embedded stack widget (`LogoSplashWidget`) layouts.
* **Instant Teardown & Audio Fixity:** Stops media playback and mutes audio output immediately on user skip (mouse click/keypress) or video completion, resolving background audio leaks.
* **Clean Linux Desktop Integration:** Bound `Qt.WindowType.SplashScreen` and injected `CUDA_VISIBLE_DEVICES=""` prior to Qt imports to suppress secondary taskbar icons and failing CUDA probe warnings.

##### 4. Nuitka Standalone Compilation & CI/CD Hardening
* **Optimized Release Builder (`build_release_damm.sh`):** Compiles Linux x86_64 standalone binaries with `--onefile`, `--lto=no`, `--low-memory`, `--jobs=2`, and `ccache` integration. Achieved 36.5% payload compression (~73.7 MB binary executable).
* **GStreamer Dependency Resolution:** Bundled runtime shared libraries (`libgstreamer1.0-0`, `libgstreamer-plugins-base1.0-0`, `gstreamer1.0-plugins-good`, `gstreamer1.0-libav`, `gstreamer1.0-gl`), eliminating build and execution conflicts on Linux runners.
* **Standalone Path Resolution:** Dynamic path resolution using `$NUITKA_ONEFILE_DIRECTORY` for icons, media, and tools in `--onefile` extraction mode.

##### 5. UI Polish & Brand Standardization
* **Brand Ratification:** Completed standardization to **digiArchive** across all window titles, metadata files, and user documentation .
* **Refactored Module Structure:** Standardized maintenance scripts into `src/t_*.py` modules (`t_load_schema`, `t_schema_extractor`, `t_catalog_integrity_audit`, `t_db_backup`).

---

#### 🧪 Quality Assurance & Test Verification
* **Test Suite Status:** 27/27 core regression tests passing via `tests_suite/run_tests.py` .
* **Hardened Test Status:** 11/11 hardened regression tests passing via pre-commit hook (total 38/38 pre-commit test suites passing).
* **CI Quality Gate:** All tests execute and verify fixity, schema idempotency, and device discovery before standalone binary packaging.

---

#### 📦 Release Artifacts

| Artifact                              | Type              | Description                                                 |
|:--------------------------------------|:------------------|:------------------------------------------------------------|
| `digiArchive-linux-x86_64.bin`        | Standalone Binary | Compiled standalone Linux executable (zero-dependency)      |
| `digiArchive-linux-x86_64.bin.sha256` | Checksum          | SHA-256 verification hash                                   |
| `installers/install-digiarchive.sh`   | Shell Script      | Automated system installer with GStreamer pre-flight checks |
| `installers/uninstall-digiarchive.sh` | Shell Script      | System uninstallation script                                |
| `CHANGELOG.md`                        | Documentation     | Complete version history including v5.0.1 changes           |
| `RELEASE_NOTES_v5.0.1.md`             | Documentation     | Official v5.0.1 release notes                               |

---

*digiArchive Development Team — October 2026*
