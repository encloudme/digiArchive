# Changelog

All notable changes to the digiArchive project are documented in this file.

## [v5.0.0 (stable)] - 2026-10-12

### Added
- Decoupled Database Mode: Support running catalog.db decoupled outside vault root.
- Modular Schema Loader Delegation: Delegated catalog initialization to src/tools/load_schema.py.
- Dedicated License Sub-Tab: Added Sub-Tab 0 displaying MIT license terms and repository links.
- GFS Snapshot Catalog: Interactive UI table and controls in Settings Sub-Tab 5.5 for automated snapshots.
- Packaging and Installer Suite: Added shell installation and removal scripts.

### Changed
- Settings Sub-Tabs Architecture Overhaul: Reorganized Settings view into six modular sub-tabs.
- Theme Ratification: Restored contrast across both Dark and Light desktop palettes.
- UI Mnemonic Escaping: Escaped Qt accelerator mnemonics to resolve character underlines.
- Dialog Rich-Text Normalization: Enforced explicit HTML formatting across modal dialogs.

### Fixed
- Silent Database Creation Failure: Ensured return value checks on schema loader.
- Preserved Schema Loader Backup: Maintained load_schema_bkup.py.

## [5.0.0-rc.1] - 2026-10-06

### Added
- Single-File Nuitka Packaging Workflow: Configured automated build workflow for standalone binaries.
- Dynamic 2FA QR Onboarding: Integrated Base32 TOTP secret generation and QR modal.
- Automated DDL Export: Updated schema_extractor.py to output both documentation and DDL.

### Changed
- Dynamic Vault Pathing: Centralized vault variables in config.py.
- Window Title Branding: Enforced uniform window titles across dialog triggers.

### Fixed
- Threading and Async Crash Prevention: Prevented thread collection crashes and aligned mouse event signatures.
- Runtime Import and Syntax Errors: Added missing Path import in cleaner UI and guarded device classification.
- Tilde Path Expansion: Fixed literal tilde string resolution using Path.expanduser().
- GUI Type Safety: Cast output_dir explicitly to string when binding to UI line edits.

## [5.0.0] - 2026-10-02

### Added
- Automated Pre-Commit Safety Checks: Configured checks prior to local commits.
- Dual-Privacy Reporting Model: Established forensic diagnostics alongside shareable summaries.

### Changed
- Complete Test Suite Verification: Achieved 38/38 passing test suites across database and safety rules.
- Environment Isolation: Updated gitignore to isolate virtual environments and IDE settings.

## [4.6.0] - 2026-10-01

### Added
- Application Rebranding: Formal project rebranding to digiArchive with updated assets and desktop launchers.

### Removed
- Legacy Artifact Cleanup: Pruned obsolete prototype scripts and temporary test files.

## [0.2.0] - 2026-08-29

### Added
- Modular Package Structure: Refactored standalone scripts into reusable core subpackages (catalog, devices, ingestion, duplicates, integrity, restore, media, ui).
- Authoritative Catalog Schema: Formally established relational SQLite schema with foreign key enforcement and cascading deletes.
- Hardware Profile and Signature Model: Added device_profiles and device_identifiers (ADB serials, mount nodes).
- Non-Destructive Ingestion Engine: Introduced delta evaluation separating physical occurrences from deduplicated logical master files.
- Desktop Application Baseline: Added initial desktop UI and CLI entry points.

## [0.1.0] - 2026-08-24

### Added
- Baseline Ingestion and Catalog Layout: Initial commit establishing prototype scripts, database schema, media duplicate handling, canonical planning queries, and logging.
