-- ==============================================================================
-- 🗄️ digiArchive — Catalog Database Unified Master Schema (v3.1 / v5.0.1)
-- ==============================================================================
-- Architecture: Single Source of Truth for Catalog Metadata, File Provenance,
-- Transactional Ingestion/Sync Auditing, and Vault Security (FR-18).
-- ==============================================================================

PRAGMA foreign_keys = ON;

-- ------------------------------------------------------------------------------
-- 1. Vault Security & Self-Contained Identity (FR-18)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vault_security (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Triggers: Enforce db_uuid Immutability
CREATE TRIGGER IF NOT EXISTS lock_db_uuid_update
BEFORE UPDATE ON vault_security
FOR EACH ROW
WHEN OLD.key = 'db_uuid'
BEGIN
    SELECT RAISE(FAIL, 'CRITICAL ERROR: db_uuid is immutable and cannot be modified.');
END;

CREATE TRIGGER IF NOT EXISTS lock_db_uuid_delete
BEFORE DELETE ON vault_security
FOR EACH ROW
WHEN OLD.key = 'db_uuid'
BEGIN
    SELECT RAISE(FAIL, 'CRITICAL ERROR: db_uuid cannot be deleted from vault_security.');
END;

-- ------------------------------------------------------------------------------
-- 2. Registered Devices & Hardware Profiles
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    device_name TEXT NOT NULL,
    device_type TEXT NOT NULL DEFAULT 'SOURCE',
    description TEXT,
    active INTEGER DEFAULT 1 CHECK(active IN (0, 1)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS device_profiles (
    device_id TEXT PRIMARY KEY,
    device_uuid TEXT UNIQUE,
    manufacturer TEXT,
    model TEXT,
    os_name TEXT,
    os_version TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS device_identifiers (
    device_id TEXT NOT NULL,
    identifier_type TEXT NOT NULL,
    identifier_value TEXT NOT NULL,
    is_primary INTEGER DEFAULT 0 CHECK(is_primary IN (0, 1)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier_type, identifier_value),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 3. Logical File Registry (MASTER Catalog Identity)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS files (
    file_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sha256 TEXT NOT NULL UNIQUE,
    master_path TEXT,
    canonical_path TEXT,
    filename TEXT,
    extension TEXT,
    size_bytes INTEGER,
    status TEXT DEFAULT 'MASTER',
    storage_state TEXT DEFAULT 'IN_MASTER',
    mime_type TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 4. Physical Source Occurrences (Asset Inventory)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS asset_inventory (
    asset_id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    source_path TEXT NOT NULL,
    source_filename TEXT,
    relative_path TEXT,
    sha256 TEXT,
    size_bytes INTEGER,
    extension TEXT,
    category TEXT DEFAULT 'OTHER',
    inventory_status TEXT DEFAULT 'INVENTORIED',
    keep_decision TEXT DEFAULT 'KEEP',
    duplicate_status TEXT DEFAULT 'UNIQUE',
    inventory_source TEXT DEFAULT 'SCANNER',
    source_modified_at TEXT,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (device_id, source_path),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 5. Physical-to-Logical Mapping & Source Provenance
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS asset_map (
    map_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL,
    file_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (asset_id, file_id),
    FOREIGN KEY (asset_id) REFERENCES asset_inventory(asset_id) ON DELETE CASCADE,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS file_sources (
    file_id INTEGER NOT NULL,
    device_id TEXT NOT NULL,
    source_path TEXT NOT NULL,
    source_filename TEXT,
    source_size_bytes INTEGER,
    source_sha256 TEXT,
    source_modified_date TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (file_id, device_id, source_path),
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 6. Ingestion Sessions & Transfer Manifests
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_sessions (
    session_id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL,
    destination_root TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'IN_PROGRESS',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    total_files INTEGER NOT NULL DEFAULT 0,
    files_scanned INTEGER DEFAULT 0,
    verified_files INTEGER NOT NULL DEFAULT 0,
    failed_files INTEGER NOT NULL DEFAULT 0,
    copied_files INTEGER NOT NULL DEFAULT 0,
    duplicate_skipped INTEGER NOT NULL DEFAULT 0,
    bytes_transferred INTEGER DEFAULT 0,
    safe_to_disconnect INTEGER NOT NULL DEFAULT 0 CHECK(safe_to_disconnect IN (0, 1)),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS copy_manifest (
    manifest_id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL,
    source_device_id TEXT NOT NULL,
    source_path TEXT NOT NULL,
    destination_path TEXT NOT NULL,
    source_sha256 TEXT NOT NULL,
    destination_sha256 TEXT,
    source_size_bytes INTEGER,
    destination_size_bytes INTEGER,
    copied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'PENDING',
    verification_method TEXT DEFAULT 'SHA256',
    notes TEXT,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE,
    FOREIGN KEY (source_device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 7. Deletion Events & Quarantine Auditing
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS deletion_events (
    deletion_id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER,
    device_id TEXT NOT NULL,
    original_path TEXT NOT NULL,
    bin_path TEXT NOT NULL,
    reason TEXT,
    sha256 TEXT,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE SET NULL,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 8. Classification, Overrides & Duplicate Management
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS duplicate_groups (
    duplicate_group_id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_sha256 TEXT UNIQUE NOT NULL,
    chosen_file_id INTEGER,
    decision TEXT DEFAULT 'PENDING_REVIEW',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (chosen_file_id) REFERENCES files(file_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS duplicate_members (
    duplicate_group_id INTEGER NOT NULL,
    file_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (duplicate_group_id, file_id),
    FOREIGN KEY (duplicate_group_id) REFERENCES duplicate_groups(duplicate_group_id) ON DELETE CASCADE,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS asset_manual_modify (
    modify_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL,
    manual_category TEXT,
    manual_keep_decision TEXT,
    apply_status TEXT DEFAULT 'APPLIED',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (asset_id) REFERENCES asset_inventory(asset_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS file_manual_modify (
    modify_id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL,
    manual_canonical_path TEXT,
    apply_status TEXT DEFAULT 'APPLIED',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS asset_decision_history (
    history_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL,
    previous_decision TEXT,
    new_decision TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (asset_id) REFERENCES asset_inventory(asset_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS file_decision_history (
    history_id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL,
    previous_path TEXT,
    new_path TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 9. Performance Indexes
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_files_sha256 ON files(sha256);
CREATE INDEX IF NOT EXISTS idx_asset_inventory_lookup ON asset_inventory(device_id, source_path);
CREATE INDEX IF NOT EXISTS idx_asset_inventory_sha256 ON asset_inventory(sha256);
CREATE INDEX IF NOT EXISTS idx_asset_map_pair ON asset_map(asset_id, file_id);
CREATE INDEX IF NOT EXISTS idx_copy_manifest_file ON copy_manifest(file_id);
CREATE INDEX IF NOT EXISTS idx_sync_sessions_device ON sync_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_deletion_events_device ON deletion_events(device_id);