CREATE TABLE asset_decision_history (
    decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL,
    category TEXT,
    keep_decision TEXT,
    manual_category TEXT,
    manual_keep_decision TEXT,
    manual_canonical_path TEXT,
    sys_proposed_canonical_path TEXT,
    manual_notes TEXT,
    decision_source TEXT NOT NULL,
    decision_timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (asset_id)
        REFERENCES asset_inventory(asset_id)
        ON DELETE CASCADE
);

CREATE TABLE asset_inventory (
    asset_id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Physical occurrence identity
    device_id TEXT NOT NULL,
    source_path TEXT NOT NULL,
    source_filename TEXT,
    relative_path TEXT,

    -- Content identity
    sha256 TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,

    -- File classification
    extension TEXT,
    content_type TEXT,
    category TEXT NOT NULL DEFAULT 'OTHER',

    -- Source timestamps
    source_created_at TEXT,
    source_modified_at TEXT,
    source_accessed_at TEXT,
    source_ctime_at TEXT,

    -- Inventory / decision state
    inventory_status TEXT NOT NULL DEFAULT 'INVENTORIED',
    keep_decision TEXT NOT NULL DEFAULT 'REVIEW',

    -- Duplicate information
    duplicate_status TEXT,
    duplicate_reason TEXT,
    duplicate_group_id TEXT,

    -- Audit
    first_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, inventory_source TEXT,

    FOREIGN KEY(device_id)
        REFERENCES devices(device_id),

    UNIQUE(device_id, source_path)
);

CREATE TABLE asset_manual_modify (
    asset_id INTEGER PRIMARY KEY,

    manual_category TEXT,
    manual_keep_decision TEXT,

    manual_canonical_path TEXT,
    sys_proposed_canonical_path TEXT,

    manual_notes TEXT,

    modified_by TEXT,
    modified_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    applied_at TEXT,
    apply_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (
            apply_status IN (
                'PENDING',
                'APPROVED',
                'APPLIED',
                'REJECTED'
            )
        ),

    FOREIGN KEY (asset_id)
        REFERENCES asset_inventory(asset_id)
        ON DELETE CASCADE
);

CREATE TABLE asset_map (
    asset_id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (asset_id)
        REFERENCES asset_inventory(asset_id)
        ON DELETE CASCADE,

    FOREIGN KEY (file_id)
        REFERENCES files(file_id)
        ON DELETE CASCADE
);

CREATE TABLE asset_metadata (
    asset_id INTEGER PRIMARY KEY,

    mime_type TEXT,

    width INTEGER,
    height INTEGER,
    orientation TEXT,

    duration_seconds REAL,
    bitrate INTEGER,
    sample_rate INTEGER,
    codec TEXT,

    camera_make TEXT,
    camera_model TEXT,
    capture_date TEXT,

    artist TEXT,
    album TEXT,
    title TEXT,

    metadata_json TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

  
    FOREIGN KEY (asset_id)
        REFERENCES asset_inventory(asset_id)
        ON DELETE CASCADE
);

CREATE TABLE copy_manifest(manifest_id INTEGER PRIMARY KEY AUTOINCREMENT,file_id INTEGER NOT NULL,source_device_id TEXT NOT NULL,source_path TEXT NOT NULL,destination_path TEXT NOT NULL,source_sha256 TEXT NOT NULL,destination_sha256 TEXT,source_size_bytes INTEGER,destination_size_bytes INTEGER,copied_at TEXT,verified_at TEXT,status TEXT NOT NULL DEFAULT 'PLANNED' CHECK(status IN('PLANNED','COPIED','VERIFIED','FAILED','SKIPPED')),verification_method TEXT,error_message TEXT,notes TEXT,FOREIGN KEY(file_id) REFERENCES files(file_id) ON DELETE CASCADE,FOREIGN KEY(source_device_id) REFERENCES devices(device_id));

CREATE TABLE deletion_events (
    deletion_id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER,
    device_id TEXT NOT NULL,
    original_path TEXT,
    deleted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    bin_path TEXT,
    reason TEXT,
    sha256 TEXT,
    notes TEXT,
    FOREIGN KEY(file_id) REFERENCES files(file_id),
    FOREIGN KEY(device_id) REFERENCES devices(device_id)
);

CREATE TABLE device_identifiers (
    device_identifier_id INTEGER PRIMARY KEY AUTOINCREMENT,

    device_id TEXT NOT NULL,

    identifier_type TEXT NOT NULL,
    identifier_value TEXT NOT NULL,
    is_primary INTEGER NOT NULL DEFAULT 0,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (device_id)
        REFERENCES devices(device_id)
        ON DELETE CASCADE,

    UNIQUE(identifier_type, identifier_value)
);

CREATE TABLE device_profiles (
    device_id TEXT PRIMARY KEY,

    device_uuid TEXT,
    manufacturer TEXT,
    model TEXT,
    os_name TEXT,
    os_version TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (device_id)
        REFERENCES devices(device_id)
        ON DELETE CASCADE
);

CREATE TABLE devices (
    device_id TEXT PRIMARY KEY,
    device_name TEXT NOT NULL UNIQUE,
    device_type TEXT NOT NULL,
    description TEXT,
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE duplicate_groups (
    duplicate_group_id TEXT PRIMARY KEY,
    sha256 TEXT NOT NULL,
    decision TEXT NOT NULL DEFAULT 'REVIEW' CHECK(decision IN ('REVIEW','KEEP_ONE','KEEP_ALL','IGNORE')),
    chosen_file_id INTEGER,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(chosen_file_id) REFERENCES files(file_id)
);

CREATE TABLE duplicate_members (
    duplicate_group_id TEXT NOT NULL,
    file_id INTEGER NOT NULL,
    PRIMARY KEY(duplicate_group_id, file_id),
    FOREIGN KEY(duplicate_group_id) REFERENCES duplicate_groups(duplicate_group_id) ON DELETE CASCADE,
    FOREIGN KEY(file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

CREATE TABLE file_decision_history (
  decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id INTEGER NOT NULL,
  manual_category TEXT,
  manual_canonical_path TEXT,
  sys_proposed_canonical_path TEXT,
  manual_notes TEXT,
  review_status TEXT,
  reviewed_at TEXT,
  reviewed_by TEXT,
  decision_source TEXT NOT NULL,
  decision_timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (file_id) REFERENCES files (file_id) ON DELETE CASCADE
);

CREATE TABLE file_manual_modify (
    file_id INTEGER PRIMARY KEY,

    manual_canonical_path TEXT,
    sys_proposed_canonical_path TEXT,

    manual_notes TEXT,

    modified_by TEXT,
    modified_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    applied_at TEXT,
    apply_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (
            apply_status IN (
                'PENDING',
                'APPROVED',
                'APPLIED',
                'REJECTED'
            )
        ),

    decision_source TEXT,

    FOREIGN KEY (file_id)
        REFERENCES files(file_id)
        ON DELETE CASCADE
);

CREATE TABLE file_xattrs (
    file_id INTEGER PRIMARY KEY,
    xattr_supported INTEGER NOT NULL DEFAULT 0 CHECK(xattr_supported IN (0,1)),
    xattr_applied INTEGER NOT NULL DEFAULT 0 CHECK(xattr_applied IN (0,1)),
    xattr_names TEXT,
    last_checked_at TEXT,
    FOREIGN KEY(file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

CREATE TABLE files (
    file_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sha256 TEXT NOT NULL,
    master_path TEXT,
    filename TEXT NOT NULL,
    extension TEXT,
    size_bytes INTEGER NOT NULL,
    media_type TEXT,
    capture_date TEXT,
    created_date TEXT,
    modified_date TEXT,
    status TEXT NOT NULL DEFAULT 'MASTER',
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, canonical_path TEXT, storage_state TEXT NOT NULL DEFAULT 'IN_MASTER' CHECK(storage_state IN ('IN_MASTER','MOVED_EXTERNAL','IN_BIN','MISSING')), external_device_id TEXT, external_path TEXT, moved_out_at TEXT, storage_move_reason TEXT,
    UNIQUE(sha256, master_path)
);

CREATE TABLE folders(folder_id INTEGER PRIMARY KEY AUTOINCREMENT,master_path TEXT NOT NULL UNIQUE,folder_name TEXT NOT NULL,parent_path TEXT,folder_type TEXT,description TEXT,device_summary TEXT,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE restore_preferences (
    file_id INTEGER NOT NULL,
    device_id TEXT NOT NULL,
    restore_enabled INTEGER NOT NULL DEFAULT 1 CHECK(restore_enabled IN (0,1)),
    target_relative_path TEXT,
    notes TEXT,
    PRIMARY KEY(file_id, device_id),
    FOREIGN KEY(file_id) REFERENCES files(file_id) ON DELETE CASCADE,
    FOREIGN KEY(device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

CREATE TABLE sync_sessions (
                session_id TEXT PRIMARY KEY,
                device_id TEXT NOT NULL,
                destination_root TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                total_files INTEGER NOT NULL,
                safe_to_disconnect INTEGER NOT NULL CHECK(safe_to_disconnect IN (0,1)),
                FOREIGN KEY(device_id) REFERENCES devices(device_id) ON DELETE CASCADE
            );

CREATE TABLE z_canonical_plan_legacy (
    plan_id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL UNIQUE,
    current_canonical_path TEXT,
    proposed_canonical_path TEXT NOT NULL,
    proposal_rule TEXT,
    proposal_reason TEXT,
    review_status TEXT NOT NULL DEFAULT 'REVIEW'
        CHECK(review_status IN ('REVIEW','APPROVED','REJECTED','APPLIED')),
    reviewed_at TEXT,
    reviewed_by TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    manual_canonical_path TEXT,
    manual_category TEXT,
    manual_notes TEXT
);

CREATE TRIGGER z_canonical_plan_legacy_no_delete
BEFORE DELETE ON z_canonical_plan_legacy
BEGIN
    SELECT RAISE(
        ABORT,
        'LEGACY TABLE READ-ONLY: z_canonical_plan_legacy'
    );
END;

CREATE TRIGGER z_canonical_plan_legacy_no_insert
BEFORE INSERT ON z_canonical_plan_legacy
BEGIN
    SELECT RAISE(
        ABORT,
        'LEGACY TABLE READ-ONLY: z_canonical_plan_legacy'
    );
END;

CREATE TRIGGER z_canonical_plan_legacy_no_update
BEFORE UPDATE ON z_canonical_plan_legacy
BEGIN
    SELECT RAISE(
        ABORT,
        'LEGACY TABLE READ-ONLY: z_canonical_plan_legacy'
    );
END;

CREATE TABLE z_file_sources_legacy (
    file_id INTEGER NOT NULL,
    device_id TEXT NOT NULL,
    source_path TEXT,
    source_filename TEXT,
    source_size_bytes INTEGER,
    source_sha256 TEXT NOT NULL,
    source_modified_date TEXT,
    first_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY(file_id, device_id, source_path)
);

CREATE TRIGGER z_file_sources_legacy_no_delete
BEFORE DELETE ON z_file_sources_legacy
BEGIN
    SELECT RAISE(
        ABORT,
        'LEGACY TABLE READ-ONLY: z_file_sources_legacy'
    );
END;

CREATE TRIGGER z_file_sources_legacy_no_insert
BEFORE INSERT ON z_file_sources_legacy
BEGIN
    SELECT RAISE(
        ABORT,
        'LEGACY TABLE READ-ONLY: z_file_sources_legacy'
    );
END;

CREATE TRIGGER z_file_sources_legacy_no_update
BEFORE UPDATE ON z_file_sources_legacy
BEGIN
    SELECT RAISE(
        ABORT,
        'LEGACY TABLE READ-ONLY: z_file_sources_legacy'
    );
END;

CREATE TABLE z_media_copy_manifest_legacy (
    manifest_id INTEGER PRIMARY KEY AUTOINCREMENT,

    batch_id TEXT NOT NULL,
    inventory_id INTEGER NOT NULL,

    source_device_id TEXT NOT NULL,
    source_path TEXT NOT NULL,
    destination_path TEXT,

    source_sha256 TEXT NOT NULL,
    destination_sha256 TEXT,

    source_size_bytes INTEGER NOT NULL,
    destination_size_bytes INTEGER,

    category TEXT NOT NULL,

    copied_at TEXT,
    verified_at TEXT,

    status TEXT NOT NULL DEFAULT 'PLANNED'
        CHECK (
            status IN (
                'PLANNED',
                'COPIED',
                'VERIFIED',
                'FAILED',
                'SKIPPED'
            )
        ),

    verification_method TEXT,
    error_message TEXT,
    notes TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (inventory_id)
        REFERENCES z_multi_media_assets_legacy(inventory_id)
        ON DELETE CASCADE
);

CREATE TRIGGER z_media_copy_manifest_legacy_no_delete
BEFORE DELETE ON z_media_copy_manifest_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_media_copy_manifest_legacy');
END;

CREATE TRIGGER z_media_copy_manifest_legacy_no_insert
BEFORE INSERT ON z_media_copy_manifest_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_media_copy_manifest_legacy');
END;

CREATE TRIGGER z_media_copy_manifest_legacy_no_update
BEFORE UPDATE ON z_media_copy_manifest_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_media_copy_manifest_legacy');
END;

CREATE TABLE z_media_metadata_legacy (
    inventory_id INTEGER PRIMARY KEY,

    mime_type TEXT,
    width INTEGER,
    height INTEGER,
    orientation TEXT,

    duration_seconds REAL,
    bitrate INTEGER,
    sample_rate INTEGER,
    codec TEXT,

    camera_make TEXT,
    camera_model TEXT,
    capture_date TEXT,

    artist TEXT,
    album TEXT,
    title TEXT,

    metadata_json TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (inventory_id)
        REFERENCES z_multi_media_assets_legacy(inventory_id)
        ON DELETE CASCADE
);

CREATE TRIGGER z_media_metadata_legacy_no_delete
BEFORE DELETE ON z_media_metadata_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_media_metadata_legacy');
END;

CREATE TRIGGER z_media_metadata_legacy_no_insert
BEFORE INSERT ON z_media_metadata_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_media_metadata_legacy');
END;

CREATE TRIGGER z_media_metadata_legacy_no_update
BEFORE UPDATE ON z_media_metadata_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_media_metadata_legacy');
END;

CREATE TABLE "z_multi_media_assets_legacy" (
    inventory_id INTEGER PRIMARY KEY AUTOINCREMENT,

    batch_id TEXT NOT NULL,

    source_device_id TEXT NOT NULL,

    source_path TEXT NOT NULL,
    relative_path TEXT,

    filename TEXT NOT NULL,
    extension TEXT,

    category TEXT NOT NULL,
    -- PHOTO / MUSIC / VIDEO / ARCHIVE / EBOOK / OTHER

    size_bytes INTEGER NOT NULL,
    sha256 TEXT NOT NULL,

    duplicate_group TEXT,
    duplicate_status TEXT,
    -- UNIQUE / DUPLICATE_EXACT

    keep_decision TEXT,
    -- KEEP / EXCLUDE / REVIEW

    proposed_category TEXT,
    proposed_canonical_path TEXT,

    manual_category TEXT,
    manual_canonical_path TEXT,
    manual_notes TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
, source_created_at TEXT, source_modified_at TEXT, source_accessed_at TEXT, source_ctime_at TEXT, duplicate_reason TEXT);

CREATE TRIGGER z_mma_legacy_no_delete
BEFORE DELETE ON z_multi_media_assets_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_multi_media_assets_legacy');
END;

CREATE TRIGGER z_mma_legacy_no_insert
BEFORE INSERT ON z_multi_media_assets_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_multi_media_assets_legacy');
END;

CREATE TRIGGER z_mma_legacy_no_update
BEFORE UPDATE ON z_multi_media_assets_legacy
BEGIN
    SELECT RAISE(ABORT, 'LEGACY TABLE READ-ONLY: z_multi_media_assets_legacy');
END;
