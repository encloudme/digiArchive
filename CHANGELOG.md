### Changelog
All notable changes to the digiArchive project are documented in this file.

#### [5.0.1] - 2026-10-25
##### Added
* **FR-18 Vault Security Schema Table (`vault_security`):** Integrated `vault_security` table into SQLite `schema.sql` (v3.1) storing `db_uuid` (immutable UUID v4), `admin_hash`, `totp_secret`, and `vault_name` directly within `catalog.db`.
* **Immutable UUID Triggers:** Added SQLite triggers enforcing `db_uuid` immutability against modifications or deletions.
* **Idempotent Credential Auto-Migration:** Implemented startup migration in `digiArchive.py` porting legacy credentials from `config.json` into `catalog.db` (`vault_security` table) and pruning sensitive keys from disk config files.
* **Dev 2FA QR CLI Generator (`scripts/generate_dev_qr.py`):** Added CLI utility generating scannable 2FA QR code PNG images using existing database TOTP secrets via `generate_qr_from_existing_secret()`.
* **Dual-Mode Splash Screen (`LogoSplashWidget` & `LogoSplashDialog`):** Added support for both modal dialog and embedded stack widget video splash rendering in `welcome_ui.py`.
* **Production Nuitka Release Builder (`build_release_damm.sh`):** Shell compilation script optimized for Linux x86_64 binaries with memory safety flags, ccache support, and build manifest generation.
* **Startup Logo Video Splash (LogoSplashDialog):** Integrated 12-second brand launch intro video (`digiArchive_launch.mp4`) with smooth playback via PySide6 `QMediaPlayer`, `QAudioOutput`, and `QVideoWidget`.
* **First-Run Dynamic 2FA QR Enrollment:** Added interactive `InitialSetupDialog` modal on fresh database launch rendering dynamic Base32 TOTP secret, provisioning URI, and native QPixmap QR code (zero PIL/Pillow dependency).
* **Custom Admin Password Configuration:** Enabled customizable admin password with 8+ character validation, SHA-256 password hashing, and atomic credential storage.
* **GStreamer Dependency Check in Installer:** Added pre-flight check for GStreamer 1.0 runtime libraries in `installers/install-digiarchive.sh`.
* **Nuitka Memory Guards:** Introduced `--lto=no`, `--low-memory`, `--jobs=2`, and `--disable-ccache` in `.github/workflows/nuitka-build-linux.yml` to prevent linker memory exhaustion on CI runners.

##### Changed
* **Enforced Vault Catalog Path Architecture:** Strictly anchored catalog database initialization to `<vault_root>/.archive/catalog.db`, preventing root-level directory clutter.
* **Branding Ratification:** Standardized all UI titles, dialog headers, documentation, and metadata to **digiArchive**.
* **Runtime Asset Resolution for Standalone Binaries:** Updated `src/config.py` and `src/welcome_ui.py` to anchor icon and video asset paths dynamically to `$NUITKA_ONEFILE_DIRECTORY` in `--onefile` mode.
* **License Box Rich-Text Rendering:** Switched license preview in `InitialSetupDialog` from plain text to `setHtml()` to properly render structured HTML tables and formatting.
* **CI/CD System Dependencies:** Replaced `-dev` packages with runtime packages in GitHub Actions workflow to resolve `libunwind-dev` dependency conflicts on Ubuntu runners.
* **Maintenance Modules Restructuring:** Standardized standalone maintenance tools directly under `src/t_*.py` (`t_db_backup`, `t_load_schema`, `t_schema_extractor`, `t_catalog_integrity_audit`).

##### Fixed
* **Token Invalidation on QR Re-generation:** Replaced key re-generation with existing secret retrieval in `scripts/generate_dev_qr.py` to prevent mobile authenticator desynchronization.
* **Premature Application Shutdown on Splash Dismiss:** Added `app.setQuitOnLastWindowClosed(False)` guard in `main()` during serial splash playback to prevent Qt from terminating the app before `MainWindow.show()`.
* **Background Audio Leak on Splash Skip:** Implemented immediate audio output mute and player stop hooks in `done(r)`, mouse click, and keypress handlers in `LogoSplashDialog`.
* **Secondary Desktop Dock Icon:** Bound `Qt.WindowType.SplashScreen` window flag to suppress duplicate taskbar/dock gear icons on Linux desktop window managers.
* **Hardware Acceleration Warning Suppression:** Forced `CUDA_VISIBLE_DEVICES=""` prior to Qt/multimedia imports to suppress failing CUDA probe errors and enforce reliable CPU decoding.
* **IDE Static Analysis & KPI Card Subclassing:** Subclassed `KPICard(QFrame)` with explicit `self.val_label` attribute to eliminate unresolved attribute warnings.
* **Vault Unlock Confirmation Wording:** Corrected grammatical typo in settings dialog copy to confirm 2FA credentials remain unchanged when switching catalog databases.

#### [5.0.0] - 2026-10-12
##### Added
* **Decoupled Database Mode:** Support running `catalog.db` decoupled outside vault root with automated path mismatch detection and migration assistance.
* **Modular Schema Loader Delegation:** Delegated catalog initialization directly to `src/t_load_schema.py`, eliminating raw embedded SQL DDL in UI code.
* **Dedicated License Sub-Tab:** Added Sub-Tab 0 displaying MIT license terms, developer metadata, and repository links with native browser integration.
* **GFS Snapshot Catalog:** Interactive UI table and controls in Settings Sub-Tab 5.5 for automated Grandfather-Father-Son database snapshots.
* **Packaging and Installer Suite:** Added automated shell installation (`install-digiarchive.sh`) and removal (`uninstall-digiarchive.sh`) scripts.

##### Changed
* **Settings Sub-Tabs Architecture Overhaul:** Reorganized Settings view into six modular sub-tabs (License, Master Vault, Database Ops, Diagnostics Log, Cron, GFS).
* **Theme Ratification:** Restored contrast across both Slate Obsidian (Dark) and Zinc Alabaster (Light) desktop palettes.
* **UI Mnemonic Escaping:** Escaped Qt accelerator mnemonics (`&&`) to resolve raw character underlines in tab labels and group boxes.
* **Dialog Rich-Text Normalization:** Enforced explicit `<html>...<br>` formatting across modal dialogs to prevent unparsed markup display.

##### Fixed
* **Silent Database Creation Failure:** Ensured return value checks on schema loader and redirected diagnostics to console log.
* **Preserved Schema Loader Backup:** Maintained schema loader recovery fallback (`load_schema_bkup.py`).

#### [5.0.0-rc.1] - 2026-10-06
##### Added
* **Single-File Nuitka Packaging Workflow:** Configured automated build workflow for standalone binaries via GitHub Actions.
* **Dynamic 2FA QR Onboarding:** Integrated Base32 TOTP secret generation and QR modal.
* **Automated DDL Export:** Updated `schema_extractor.py` to output both documentation and DDL.

##### Changed
* **Dynamic Vault Pathing:** Centralized vault variables in `config.py` as single source of truth.
* **Window Title Branding:** Enforced uniform window titles and status emojis across dialog triggers.

##### Fixed
* **Threading and Async Crash Prevention:** Prevented thread collection crashes and aligned mouse event signatures.
* **Runtime Import and Syntax Errors:** Added missing `Path` import in cleaner UI and guarded device classification.
* **Tilde Path Expansion:** Fixed literal tilde string resolution using `Path.expanduser()`.
* **GUI Type Safety:** Cast `output_dir` explicitly to string when binding to UI line edits.

#### [5.0.0-beta.1] - 2026-10-02
##### Added
* **Automated Pre-Commit Safety Checks:** Configured automated test suite execution prior to local git commits.
* **Dual-Privacy Reporting Model:** Established forensic diagnostics (`LOCAL_FULL_DO_NOT_SHARE`) alongside sanitized summaries (`SAFE_SUMMARY_SHAREABLE`).

##### Changed
* **Complete Test Suite Verification:** Achieved 38/38 passing test suites across database and safety rules.
* **Environment Isolation:** Updated `.gitignore` to isolate virtual environments and IDE settings.

#### [4.6.0] - 2026-10-01
##### Added
* **Application Rebranding:** Formal project rebranding to **digiArchive** with updated assets and desktop launchers.

##### Removed
* **Legacy Artifact Cleanup:** Pruned obsolete prototype scripts and temporary test files.

#### [0.2.0] - 2026-08-29
##### Added
* **Modular Package Structure:** Refactored standalone scripts into reusable core subpackages.
* **Authoritative Catalog Schema:** Formally established relational SQLite schema with foreign key enforcement and cascading deletes.
* **Hardware Profile and Signature Model:** Added `device_profiles` and `device_identifiers`.
* **Non-Destructive Ingestion Engine:** Introduced delta evaluation separating physical occurrences from deduplicated logical master files.
* **Desktop Application Baseline:** Added initial desktop UI and CLI entry points.

#### [0.1.0] - 2026-08-24
##### Added
* **Baseline Ingestion and Catalog Layout:** Initial commit establishing prototype scripts, database schema, media duplicate handling, canonical planning queries, and logging.