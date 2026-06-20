-- Speed up per-keystroke conversion lookups. The conversion_lookups view filters
-- key_sequences by (key_sequence, input_type), but the only indexes on that table
-- reference columns that no longer exist, so the planner did a full scan of ~182k
-- rows on every lookup (~6ms each, several per keystroke). A covering index over
-- (key_sequence, input_type, input_id, n_syls) lets it seek and read everything
-- the view needs straight from the index (~0.04ms each).
create index if not exists key_sequences_lookup_index
    on key_sequences ("key_sequence", "input_type", "input_id", "n_syls");

-- Drop the stale covering indexes from migration 001. Their "numeric"/"telex"
-- columns no longer exist on key_sequences, so SQLite parsed those quoted names
-- as string literals: each indexes a constant and serves no query. Reclaim them
-- on existing installs (they are recreated by 001 on fresh builds, then dropped
-- here) so the table carries only the index the planner actually uses.
drop index if exists input_numeric_covering_index;
drop index if exists input_telex_covering_index;
