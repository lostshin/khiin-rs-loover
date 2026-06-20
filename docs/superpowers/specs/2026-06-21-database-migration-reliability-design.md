# Database Migration Reliability Design

## Goal

Make database upgrades reliable for existing installations without changing
the application binaries or undertaking unrelated bundle-size optimization.

## Current Problems

Migration 002 was changed after version-2 databases had already shipped. Those
databases do not execute 002 again, so the stale
`input_numeric_covering_index` and `input_telex_covering_index` indexes remain.

`Database::open` restores an on-disk database into memory and migrates the
in-memory connection, but it does not persist the upgraded connection. A
writable version-1 database retained by an Android upgrade therefore rebuilds
the `key_sequences_lookup_index` on every process start.

The macOS database is bundled under signed application resources. A release
must ship an already-current database so normal startup never needs to modify
that signed resource.

## Approaches Considered

### Selected: Versioned cleanup and conditional persistence

- Add migration 003 to remove the two stale indexes.
- Detect whether `migrate_to_latest` advanced `user_version` when opening an
  existing file.
- Back up the in-memory database only when its version advanced.
- Rebuild the generated resource database when migration inputs change.

This is the smallest change that fixes both upgrade paths. Android's retained,
writable database advances once, while a normal macOS release ships at the
latest version and does not rewrite its signed resource.

### Rejected: Explicit read-only and persistent database modes

Adding database modes would make caller intent explicit, but it would require
changes through `Engine`, the Swift bridge, Android JNI, CLI, and Windows call
sites. That API expansion is unnecessary for the two reported defects.

### Rejected: Copy the macOS database to Application Support

This would provide a writable database on macOS, but it changes how dictionary
updates are delivered. A persistent copy would need a separate policy for
replacing or merging new dictionary content on application upgrades. That is a
larger data-lifecycle change than this fix requires.

## Design

### Migration history

Migration 002 remains unchanged as the historical operation that creates
`key_sequences_lookup_index`. Migration 003 contains idempotent `DROP INDEX IF
EXISTS` statements for the two stale indexes. All version-2 databases therefore
have an explicit route to version 3.

### Opening an existing database

`Database::open` records the connection's `user_version` after restoring the
file, runs migrations, and reads the version again. If the version increased,
it backs up the migrated in-memory connection to the original file. If no
migration ran, startup performs no file write.

Migration or backup errors propagate to the caller. The original file is not
reported as upgraded unless the backup succeeds.

### Generated resource database

The database build task treats migration SQL and database-generation sources as
inputs to `resources/khiin.db`. A change to those inputs invalidates the output
and rebuilds it. Clean release builds and local builds therefore package a
version-3 database with only the useful lookup index.

On macOS, this build invariant prevents normal startup from attempting to
rewrite the code-signed `Contents/Resources/khiin.db`. On Android, an existing
database copied with `overwrite=false` remains writable and is upgraded and
persisted once.

## Testing

Regression tests use temporary on-disk SQLite databases and exercise the real
`Database::new` path.

1. Construct a version-2 legacy database containing all three indexes, open it,
   and assert that its in-memory schema advances to version 3 and removes the
   two stale indexes while preserving `key_sequences_lookup_index`.
2. Drop the opened `Database`, reopen the file with a raw SQLite connection,
   and assert that `user_version = 3` and the cleaned schema were persisted.
3. Run the existing `khiin` tests and regenerate the resource database. Inspect
   the generated database to confirm version 3, absence of stale indexes, and
   presence of `key_sequences_lookup_index`.

## Non-goals

- Reducing Swift, Rust, Tauri, or universal-binary size.
- Moving the macOS database to Application Support.
- Changing Android's asset overwrite policy.
- Refactoring the public `Engine` or bridge APIs.
