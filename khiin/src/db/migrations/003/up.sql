-- Migration 001 created these indexes over quoted names that are not columns.
-- SQLite treated the names as string literals, so both indexes are constant and
-- cannot accelerate a lookup.
drop index if exists input_numeric_covering_index;
drop index if exists input_telex_covering_index;
