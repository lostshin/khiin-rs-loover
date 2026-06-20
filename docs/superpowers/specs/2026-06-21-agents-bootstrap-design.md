# Agent Bootstrap Design

## Goal

Ensure repository-aware coding agents read the existing `CLAUDE.md` guidance
before working in this repository.

## Design

Create a root-level `AGENTS.md` containing one instruction: read `CLAUDE.md`
completely and follow it before doing repository work.

This keeps `CLAUDE.md` as the single source of truth. Copying its contents into
`AGENTS.md` would create duplicated instructions that could drift, while a
symbolic link may not be supported consistently by every agent host.

## Verification

Confirm that `AGENTS.md` exists at the repository root, names `CLAUDE.md`
explicitly, and introduces no duplicated project rules.
