-- Speed up per-keystroke conversion lookups. The conversion_lookups view filters
-- key_sequences by (key_sequence, input_type), but the only indexes on that table
-- reference columns that no longer exist, so the planner did a full scan of ~182k
-- rows on every lookup (~6ms each, several per keystroke). A covering index over
-- (key_sequence, input_type, input_id, n_syls) lets it seek and read everything
-- the view needs straight from the index (~0.04ms each).
create index if not exists key_sequences_lookup_index
    on key_sequences ("key_sequence", "input_type", "input_id", "n_syls");
