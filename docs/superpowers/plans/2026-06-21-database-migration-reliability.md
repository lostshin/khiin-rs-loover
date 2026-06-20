# Database Migration Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every version-2 database an explicit cleanup migration and persist successful upgrades so retained databases migrate only once.

**Architecture:** Migration 003 owns stale-index removal, preserving migration history. `Database::open` compares SQLite `user_version` before and after migration and backs up the in-memory database only when the version advances; generated resource databases are invalidated when migration or database-generation inputs change so signed macOS bundles ship current data.

**Tech Stack:** Rust, rusqlite, rusqlite_migration, SQLite, cargo-make

---

## File Structure

- Create `khiin/src/db/migrations/003/up.sql`: remove the two stale indexes for every version-2 database.
- Modify `khiin/src/db/migrations/002/up.sql`: restore the released migration to its original index-creation-only contents.
- Modify `khiin/src/db/database.rs`: register migration 003, detect version advancement, persist migrated databases, and add regression tests.
- Modify `Cargo.toml`: expose `tempfile` as a workspace test dependency.
- Modify `khiin/Cargo.toml`: use `tempfile` in database regression tests.
- Modify `Makefile.toml`: rebuild `resources/khiin.db` when migrations or database-generation inputs change.

### Task 1: Add a versioned stale-index cleanup migration

**Files:**
- Create: `khiin/src/db/migrations/003/up.sql`
- Modify: `khiin/src/db/migrations/002/up.sql:9-16`
- Modify: `khiin/src/db/database.rs:23-28,388-431`
- Modify: `Cargo.toml:10-38`
- Modify: `khiin/Cargo.toml:30-33`
- Test: `khiin/src/db/database.rs:388-431`

- [ ] **Step 1: Add the temporary-directory test dependency**

Add this workspace dependency to `Cargo.toml`:

```toml
tempfile = "3"
```

Add this development dependency to `khiin/Cargo.toml`:

```toml
tempfile.workspace = true
```

- [ ] **Step 2: Add legacy-database test helpers and the failing migration test**

Add these helpers and test to `khiin/src/db/database.rs` inside `mod tests`:

```rust
    use tempfile::TempDir;

    fn create_version_2_database() -> (TempDir, PathBuf) {
        let temp_dir = tempfile::tempdir().unwrap();
        let db_path = temp_dir.path().join("khiin.db");
        let conn = Connection::open(&db_path).unwrap();

        conn.execute_batch(
            r#"
            create table key_sequences (
                "input_id" integer not null,
                "key_sequence" text not null,
                "input_type" integer not null,
                "n_syls" integer not null,
                "p" real not null
            );
            create index input_numeric_covering_index
                on key_sequences ("numeric", "input_id");
            create index input_telex_covering_index
                on key_sequences ("telex", "input_id");
            create index key_sequences_lookup_index
                on key_sequences (
                    "key_sequence",
                    "input_type",
                    "input_id",
                    "n_syls"
                );
            pragma user_version = 2;
            "#,
        )
        .unwrap();

        drop(conn);
        (temp_dir, db_path)
    }

    fn user_version(conn: &Connection) -> i64 {
        conn.pragma_query_value(None, "user_version", |row| row.get(0))
            .unwrap()
    }

    fn index_exists(conn: &Connection, name: &str) -> bool {
        conn.query_row(
            "select exists(
                select 1 from sqlite_master
                where type = 'index' and name = ?1
            )",
            [name],
            |row| row.get(0),
        )
        .unwrap()
    }

    #[test]
    fn opening_v2_database_applies_cleanup_migration() {
        let (_temp_dir, db_path) = create_version_2_database();

        let db = Database::new(&db_path).unwrap();

        assert_eq!(user_version(&db), 3);
        assert!(!index_exists(&db, "input_numeric_covering_index"));
        assert!(!index_exists(&db, "input_telex_covering_index"));
        assert!(index_exists(&db, "key_sequences_lookup_index"));
    }
```

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```bash
cargo test --manifest-path khiin/Cargo.toml opening_v2_database_applies_cleanup_migration
```

Expected: FAIL because the opened database remains at `user_version = 2` and still contains the stale indexes.

- [ ] **Step 4: Restore migration 002 and add migration 003**

Remove the stale-index cleanup block from `khiin/src/db/migrations/002/up.sql`, leaving it as:

```sql
-- Speed up per-keystroke conversion lookups. The conversion_lookups view filters
-- key_sequences by (key_sequence, input_type), but the only indexes on that table
-- reference columns that no longer exist, so the planner did a full scan of ~182k
-- rows on every lookup (~6ms each, several per keystroke). A covering index over
-- (key_sequence, input_type, input_id, n_syls) lets it seek and read everything
-- the view needs straight from the index (~0.04ms each).
create index if not exists key_sequences_lookup_index
    on key_sequences ("key_sequence", "input_type", "input_id", "n_syls");
```

Create `khiin/src/db/migrations/003/up.sql`:

```sql
-- Migration 001 created these indexes over quoted names that are not columns.
-- SQLite treated the names as string literals, so both indexes are constant and
-- cannot accelerate a lookup.
drop index if exists input_numeric_covering_index;
drop index if exists input_telex_covering_index;
```

Register migration 003 in `khiin/src/db/database.rs`:

```rust
static MIGRATIONS: Lazy<Migrations> = Lazy::new(|| {
    Migrations::new(vec![
        M::up(include_str!("migrations/001/up.sql")),
        M::up(include_str!("migrations/002/up.sql")),
        M::up(include_str!("migrations/003/up.sql")),
    ])
});
```

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```bash
cargo test --manifest-path khiin/Cargo.toml opening_v2_database_applies_cleanup_migration
```

Expected: PASS. Migration 003 advances the in-memory connection to version 3, removes both stale indexes, and preserves the useful lookup index.

- [ ] **Step 6: Commit the versioned migration**

```bash
git add Cargo.toml khiin/Cargo.toml Cargo.lock khiin/src/db/database.rs khiin/src/db/migrations/002/up.sql khiin/src/db/migrations/003/up.sql
git commit -m "fix(db): move stale index cleanup to migration 003"
```

### Task 2: Persist successful migrations

**Files:**
- Modify: `khiin/src/db/database.rs:75-85,388-480`
- Test: `khiin/src/db/database.rs:388-480`

- [ ] **Step 1: Add the failing persistence test**

Add this test after the migration test:

```rust
    #[test]
    fn opening_v2_database_persists_migration() {
        let (_temp_dir, db_path) = create_version_2_database();

        {
            let db = Database::new(&db_path).unwrap();
            assert_eq!(user_version(&db), 3);
        }

        let persisted = Connection::open(&db_path).unwrap();
        assert_eq!(user_version(&persisted), 3);
        assert!(!index_exists(
            &persisted,
            "input_numeric_covering_index"
        ));
        assert!(!index_exists(
            &persisted,
            "input_telex_covering_index"
        ));
        assert!(index_exists(
            &persisted,
            "key_sequences_lookup_index"
        ));
    }
```

- [ ] **Step 2: Run the persistence test and verify RED**

Run:

```bash
cargo test --manifest-path khiin/Cargo.toml opening_v2_database_persists_migration
```

Expected: FAIL because the raw on-disk connection still reports `user_version = 2` after the migrated in-memory `Database` is dropped.

- [ ] **Step 3: Detect version advancement and back up only migrated databases**

Replace `Database::open` and `migrate_to_latest`, and add `user_version`, in `khiin/src/db/database.rs`:

```rust
    fn open(mut self) -> Result<Self> {
        self.restore()?;
        if self.migrate_to_latest()? {
            self.backup()?;
        }
        Ok(self)
    }

    fn migrate_to_latest(&mut self) -> Result<bool> {
        let previous_version = self.user_version()?;
        MIGRATIONS.to_latest(&mut self.conn)?;
        Ok(self.user_version()? > previous_version)
    }

    fn user_version(&self) -> Result<i64> {
        Ok(self
            .conn
            .pragma_query_value(None, "user_version", |row| row.get(0))?)
    }
```

The existing `init` and `from_csv` callers may discard the returned `bool`; they already back up the newly generated database after populating it.

- [ ] **Step 4: Run both regression tests and verify GREEN**

Run:

```bash
cargo test --manifest-path khiin/Cargo.toml opening_v2_database_ -- --nocapture
```

Expected: both `opening_v2_database_applies_cleanup_migration` and `opening_v2_database_persists_migration` PASS.

- [ ] **Step 5: Commit migration persistence**

```bash
git add khiin/src/db/database.rs
git commit -m "fix(db): persist completed database migrations"
```

### Task 3: Rebuild generated databases when migration inputs change

**Files:**
- Modify: `Makefile.toml:246-278`
- Verify: `resources/khiin.db` (generated and ignored)

- [ ] **Step 1: Demonstrate the stale generated database with the old build condition**

Run:

```bash
cargo make build-db
sqlite3 -readonly resources/khiin.db "pragma user_version; select name from sqlite_master where type = 'index' and name in ('input_numeric_covering_index', 'input_telex_covering_index', 'key_sequences_lookup_index') order by name;"
```

Expected before the `Makefile.toml` change: `cargo make build-db` skips generation because the output already exists; SQLite reports version 2 and all three indexes.

- [ ] **Step 2: Make database generation depend on all generation inputs**

Replace the `files_not_exist` condition on `[tasks.build-db]` in `Makefile.toml` with:

```toml
condition = { files_modified = { input = [
    "Cargo.toml",
    "khiin/Cargo.toml",
    "khiin/dbgen/Cargo.toml",
    "khiin/dbgen/src/**/*.rs",
    "khiin/src/db/database.rs",
    "khiin/src/db/init/**/*.rs",
    "khiin/src/db/migrations/**/*.sql",
    "data/data/conversions_all.csv",
    "data/data/frequency.csv",
], output = ["resources/khiin.db"] } }
```

Keep the existing `cargo run` command and arguments unchanged.

- [ ] **Step 3: Rebuild and inspect the resource database**

Run:

```bash
cargo make build-db
sqlite3 -readonly resources/khiin.db "pragma user_version; select name from sqlite_master where type = 'index' and name in ('input_numeric_covering_index', 'input_telex_covering_index', 'key_sequences_lookup_index') order by name;"
```

Expected: generation runs; SQLite reports version 3 and only `key_sequences_lookup_index`.

- [ ] **Step 4: Confirm an unchanged database is not rebuilt again**

Run twice:

```bash
stat -f '%m' resources/khiin.db
cargo make build-db
stat -f '%m' resources/khiin.db
```

Expected: both timestamps are identical because no generation input changed.

- [ ] **Step 5: Commit build invalidation**

```bash
git add Makefile.toml
git commit -m "build: regenerate database after migration changes"
```

### Task 4: Full verification

**Files:**
- Verify: `khiin/src/db/database.rs`
- Verify: `khiin/src/db/migrations/002/up.sql`
- Verify: `khiin/src/db/migrations/003/up.sql`
- Verify: `Makefile.toml`
- Verify: `resources/khiin.db` (generated and ignored)

- [ ] **Step 1: Format and check the changed Rust code**

Run:

```bash
cargo fmt --all -- --check
```

Expected: exit code 0 with no formatting differences.

- [ ] **Step 2: Ensure the test database is current and run the complete `khiin` test suite**

Run:

```bash
cargo make copy-db
cargo test --manifest-path khiin/Cargo.toml
```

Expected: database generation/copy succeeds and all `khiin` tests pass with zero failures.

- [ ] **Step 3: Verify the generated release input directly**

Run:

```bash
sqlite3 -readonly resources/khiin.db "pragma user_version; pragma integrity_check; select name from sqlite_master where type = 'index' and name in ('input_numeric_covering_index', 'input_telex_covering_index', 'key_sequences_lookup_index') order by name;"
```

Expected output includes version `3`, integrity result `ok`, and only `key_sequences_lookup_index`.

- [ ] **Step 4: Review the final diff and repository state**

Run:

```bash
git diff --check
git status --short
git log -4 --oneline
```

Expected: no whitespace errors; only intentional changes, if any, remain; the design and three implementation commits appear at the top of history.
