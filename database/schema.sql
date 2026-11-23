-- ==============================================================================
-- 🗄️ digiArchive — Catalog Database Unified Master Schema (v5.0.5 / Production)
-- ==============================================================================
-- Single Source of Truth for Catalog Metadata, Physical Asset Provenance,
-- Transactional Ingestion/Sync Auditing, Vault Security, and Extension Registry.
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

CREATE TABLE IF NOT EXISTS catalog_identity (
    catalog_uuid TEXT PRIMARY KEY,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 2. Registered Devices & Hardware Profiles
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    device_name TEXT NOT NULL UNIQUE,
    device_type TEXT NOT NULL DEFAULT 'SOURCE',
    description TEXT,
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS device_profiles (
    device_id TEXT PRIMARY KEY,
    device_uuid TEXT,
    manufacturer TEXT,
    model TEXT,
    os_name TEXT,
    os_version TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS device_identifiers (
    device_identifier_id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    identifier_type TEXT NOT NULL,
    identifier_value TEXT NOT NULL,
    is_primary INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
    UNIQUE(identifier_type, identifier_value)
);

-- ------------------------------------------------------------------------------
-- 3. Logical File Registry (MASTER Catalog Identity)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS files (
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
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    canonical_path TEXT,
    storage_state TEXT NOT NULL DEFAULT 'IN_MASTER' CHECK(storage_state IN ('IN_MASTER', 'MOVED_EXTERNAL', 'IN_BIN', 'MISSING')),
    external_device_id TEXT,
    external_path TEXT,
    moved_out_at TEXT,
    storage_move_reason TEXT,
    mime_type TEXT,
    UNIQUE(sha256, master_path)
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
    sha256 TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    extension TEXT,
    content_type TEXT,
    category TEXT NOT NULL DEFAULT 'OTHER',
    source_created_at TEXT,
    source_modified_at TEXT,
    source_accessed_at TEXT,
    source_ctime_at TEXT,
    inventory_status TEXT NOT NULL DEFAULT 'INVENTORIED',
    keep_decision TEXT NOT NULL DEFAULT 'REVIEW',
    duplicate_status TEXT,
    duplicate_reason TEXT,
    duplicate_group_id TEXT,
    first_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    inventory_source TEXT,
    FOREIGN KEY (device_id) REFERENCES devices(device_id),
    UNIQUE(device_id, source_path)
);

CREATE TABLE IF NOT EXISTS asset_metadata (
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
    FOREIGN KEY (asset_id) REFERENCES asset_inventory(asset_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 5. Physical-to-Logical Mapping & Source Provenance
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS asset_map (
    asset_id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    map_id INTEGER,
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

CREATE TABLE IF NOT EXISTS file_xattrs (
    file_id INTEGER PRIMARY KEY,
    xattr_supported INTEGER NOT NULL DEFAULT 0 CHECK(xattr_supported IN (0, 1)),
    xattr_applied INTEGER NOT NULL DEFAULT 0 CHECK(xattr_applied IN (0, 1)),
    xattr_names TEXT,
    last_checked_at TEXT,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 6. Ingestion Sessions & Transfer Manifests
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_sessions (
    session_id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL,
    destination_root TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    total_files INTEGER NOT NULL,
    files_scanned INTEGER DEFAULT 0,
    verified_files INTEGER NOT NULL DEFAULT 0,
    failed_files INTEGER NOT NULL DEFAULT 0,
    copied_files INTEGER NOT NULL DEFAULT 0,
    duplicate_skipped INTEGER NOT NULL DEFAULT 0,
    bytes_transferred INTEGER DEFAULT 0,
    safe_to_disconnect INTEGER NOT NULL CHECK(safe_to_disconnect IN (0, 1)),
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
    copied_at TEXT,
    verified_at TEXT,
    status TEXT NOT NULL DEFAULT 'PLANNED' CHECK(status IN ('PLANNED', 'COPIED', 'VERIFIED', 'FAILED', 'SKIPPED')),
    verification_method TEXT,
    error_message TEXT,
    notes TEXT,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE,
    FOREIGN KEY (source_device_id) REFERENCES devices(device_id)
);

-- ------------------------------------------------------------------------------
-- 7. Deletion Events & Quarantine Auditing
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS deletion_events (
    deletion_id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER,
    device_id TEXT NOT NULL,
    original_path TEXT,
    bin_path TEXT,
    reason TEXT,
    sha256 TEXT,
    deleted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (file_id) REFERENCES files(file_id),
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);

CREATE TABLE IF NOT EXISTS folders (
    folder_id INTEGER PRIMARY KEY AUTOINCREMENT,
    master_path TEXT NOT NULL UNIQUE,
    folder_name TEXT NOT NULL,
    parent_path TEXT,
    folder_type TEXT,
    description TEXT,
    device_summary TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS restore_preferences (
    file_id INTEGER NOT NULL,
    device_id TEXT NOT NULL,
    restore_enabled INTEGER NOT NULL DEFAULT 1 CHECK(restore_enabled IN (0, 1)),
    target_relative_path TEXT,
    notes TEXT,
    PRIMARY KEY (file_id, device_id),
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 8. Duplicate Management & Decision Tracking
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS duplicate_groups (
    duplicate_group_id TEXT PRIMARY KEY,
    sha256 TEXT NOT NULL,
    decision TEXT NOT NULL DEFAULT 'REVIEW' CHECK(decision IN ('REVIEW', 'KEEP_ONE', 'KEEP_ALL', 'IGNORE')),
    chosen_file_id INTEGER,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    group_sha256 TEXT,
    updated_at TIMESTAMP,
    FOREIGN KEY (chosen_file_id) REFERENCES files(file_id)
);

CREATE TABLE IF NOT EXISTS duplicate_members (
    duplicate_group_id TEXT NOT NULL,
    file_id INTEGER NOT NULL,
    created_at TIMESTAMP,
    PRIMARY KEY (duplicate_group_id, file_id),
    FOREIGN KEY (duplicate_group_id) REFERENCES duplicate_groups(duplicate_group_id) ON DELETE CASCADE,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS asset_manual_modify (
    asset_id INTEGER PRIMARY KEY,
    manual_category TEXT,
    manual_keep_decision TEXT,
    manual_canonical_path TEXT,
    sys_proposed_canonical_path TEXT,
    manual_notes TEXT,
    modified_by TEXT,
    modified_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    applied_at TEXT,
    apply_status TEXT NOT NULL DEFAULT 'PENDING' CHECK(apply_status IN ('PENDING', 'APPROVED', 'APPLIED', 'REJECTED')),
    modify_id INTEGER,
    updated_at TIMESTAMP,
    FOREIGN KEY (asset_id) REFERENCES asset_inventory(asset_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS file_manual_modify (
    file_id INTEGER PRIMARY KEY,
    manual_canonical_path TEXT,
    sys_proposed_canonical_path TEXT,
    manual_notes TEXT,
    modified_by TEXT,
    modified_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    applied_at TEXT,
    apply_status TEXT NOT NULL DEFAULT 'PENDING' CHECK(apply_status IN ('PENDING', 'APPROVED', 'APPLIED', 'REJECTED')),
    decision_source TEXT,
    modify_id INTEGER,
    updated_at TIMESTAMP,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS asset_decision_history (
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
    history_id INTEGER,
    previous_decision TEXT,
    new_decision TEXT,
    changed_at TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (asset_id) REFERENCES asset_inventory(asset_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS file_decision_history (
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
    history_id INTEGER,
    previous_path TEXT,
    new_path TEXT,
    changed_at TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 9. Extension Registry for Metadata Profiling & Auto-Enrichment
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS extension_registry (
    extension TEXT PRIMARY KEY,
    media_type TEXT NOT NULL,
    category TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Standard Data Profiles
INSERT OR IGNORE INTO extension_registry (extension, media_type, category, mime_type, description) VALUES
    ('jpg',  'image', 'PHOTO', 'image/jpeg', 'JPEG Image'),
    ('jpeg', 'image', 'PHOTO', 'image/jpeg', 'JPEG Image'),
    ('png',  'image', 'PHOTO', 'image/png', 'Portable Network Graphics'),
    ('gif',  'image', 'PHOTO', 'image/gif', 'Graphics Interchange Format'),
    ('webp', 'image', 'PHOTO', 'image/webp', 'WebP Image'),
    ('bmp',  'image', 'PHOTO', 'image/bmp', 'Bitmap Image'),
    ('heic', 'image', 'PHOTO', 'image/heic', 'High Efficiency Image Container'),
    ('heif', 'image', 'PHOTO', 'image/heif', 'High Efficiency Image Format'),
    ('tiff', 'image', 'PHOTO', 'image/tiff', 'Tagged Image File Format'),
    ('tif',  'image', 'PHOTO', 'image/tiff', 'Tagged Image File Format'),
    ('dng',  'image', 'PHOTO', 'image/x-adobe-dng', 'Adobe Digital Negative'),
    ('cr2',  'image', 'PHOTO', 'image/x-canon-cr2', 'Canon RAW 2'),

    ('mp4',  'video', 'VIDEO', 'video/mp4', 'MPEG-4 Video'),
    ('mkv',  'video', 'VIDEO', 'video/x-matroska', 'Matroska Video'),
    ('mov',  'video', 'VIDEO', 'video/quicktime', 'QuickTime Video'),
    ('avi',  'video', 'VIDEO', 'video/x-msvideo', 'Audio Video Interleave'),
    ('3gp',  'video', 'VIDEO', 'video/3gpp', '3GPP Multimedia'),
    ('webm', 'video', 'VIDEO', 'video/webm', 'WebM Video'),
    ('wmv',  'video', 'VIDEO', 'video/x-ms-wmv', 'Windows Media Video'),

    ('mp3',  'audio', 'MUSIC', 'audio/mpeg', 'MP3 Audio'),
    ('m4a',  'audio', 'MUSIC', 'audio/mp4', 'MPEG-4 Audio'),
    ('wav',  'audio', 'MUSIC', 'audio/wav', 'Waveform Audio'),
    ('flac', 'audio', 'MUSIC', 'audio/flac', 'Free Lossless Audio Codec'),
    ('aac',  'audio', 'MUSIC', 'audio/aac', 'Advanced Audio Coding'),
    ('amr',  'audio', 'MUSIC', 'audio/amr', 'Adaptive Multi-Rate Audio'),
    ('opus', 'audio', 'MUSIC', 'audio/opus', 'Opus Audio (Voice Notes)'),

    ('pdf',  'document', 'DOC', 'application/pdf', 'Portable Document Format'),
    ('doc',  'document', 'DOC', 'application/msword', 'Microsoft Word Document'),
    ('docx', 'document', 'DOC', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'Word OpenXML Document'),
    ('xls',  'document', 'DOC', 'application/vnd.ms-excel', 'Microsoft Excel Spreadsheet'),
    ('xlsx', 'document', 'DOC', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'Excel OpenXML Spreadsheet'),
    ('xlsm', 'document', 'DOC', 'application/vnd.ms-excel.sheet.macroEnabled.12', 'Excel Macro-Enabled Spreadsheet'),
    ('ppt',  'document', 'DOC', 'application/vnd.ms-powerpoint', 'PowerPoint Presentation'),
    ('pptx', 'document', 'DOC', 'application/vnd.openxmlformats-officedocument.presentationml.presentation', 'PowerPoint OpenXML Presentation'),
    ('odt',  'document', 'DOC', 'application/vnd.oasis.opendocument.text', 'OpenDocument Text'),
    ('ods',  'document', 'DOC', 'application/vnd.oasis.opendocument.spreadsheet', 'OpenDocument Spreadsheet'),
    ('txt',  'document', 'DOC', 'text/plain', 'Plain Text'),
    ('csv',  'document', 'DOC', 'text/csv', 'Comma-Separated Values'),
    ('json', 'document', 'DOC', 'application/json', 'JSON Document'),
    ('xml',  'document', 'DOC', 'application/xml', 'XML Document'),
    ('md',   'document', 'DOC', 'text/markdown', 'Markdown Document'),
    ('html', 'document', 'DOC', 'text/html', 'HTML Document'),
    ('htm',  'document', 'DOC', 'text/html', 'HTML Document'),
    ('mht',  'document', 'DOC', 'multipart/related', 'MHTML Web Archive'),
    ('vcf',  'document', 'DOC', 'text/vcard', 'vCard Contact File'),
    ('ics',  'document', 'DOC', 'text/calendar', 'iCalendar File'),
    ('srt',  'document', 'DOC', 'application/x-subrip', 'Subtitle File'),
    ('log',  'document', 'DOC', 'text/plain', 'Log File'),
    ('ini',  'document', 'DOC', 'text/plain', 'Configuration INI'),
    ('xsl',  'document', 'DOC', 'application/xslt+xml', 'XML Stylesheet'),
    ('py',   'document', 'CODE', 'text/x-python', 'Python Script'),

    ('zip',  'archive', 'ARCHIVE', 'application/zip', 'ZIP Archive'),
    ('rar',  'archive', 'ARCHIVE', 'application/vnd.rar', 'RAR Archive'),
    ('7z',   'archive', 'ARCHIVE', 'application/x-7z-compressed', '7-Zip Archive'),
    ('tar',  'archive', 'ARCHIVE', 'application/x-tar', 'Tape Archive'),
    ('gz',   'archive', 'ARCHIVE', 'application/gzip', 'Gzip Archive'),
    ('iso',  'archive', 'ARCHIVE', 'application/x-iso9660-image', 'Optical Disc Image'),

    ('apk',  'executable', 'SYSTEM', 'application/vnd.android.package-archive', 'Android Package Kit'),
    ('exe',  'executable', 'SYSTEM', 'application/vnd.microsoft.portable-executable', 'Windows Executable'),
    ('deb',  'executable', 'SYSTEM', 'application/vnd.debian.binary-package', 'Debian Package'),
    ('bin',  'system', 'SYSTEM', 'application/octet-stream', 'Binary Data File'),
    ('dat',  'system', 'SYSTEM', 'application/octet-stream', 'Generic Data File'),
    ('db',   'system', 'SYSTEM', 'application/vnd.sqlite3', 'SQLite / Database File'),
    ('nomedia', 'system', 'SYSTEM', 'application/octet-stream', 'Android Media Sentinel'),
    ('ttf',  'document', 'SYSTEM', 'font/ttf', 'TrueType Font');

-- ------------------------------------------------------------------------------
-- 10. Performance Indexes
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_files_sha256 ON files(sha256);
CREATE INDEX IF NOT EXISTS idx_files_status ON files(status);
CREATE INDEX IF NOT EXISTS idx_asset_inventory_lookup ON asset_inventory(device_id, source_path);
CREATE INDEX IF NOT EXISTS idx_asset_inventory_sha256 ON asset_inventory(sha256);
CREATE INDEX IF NOT EXISTS idx_asset_map_pair ON asset_map(asset_id, file_id);
CREATE INDEX IF NOT EXISTS idx_copy_manifest_file ON copy_manifest(file_id);
CREATE INDEX IF NOT EXISTS idx_sync_sessions_device ON sync_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_deletion_events_device ON deletion_events(device_id);