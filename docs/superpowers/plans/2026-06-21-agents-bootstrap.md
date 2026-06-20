# Agent Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a root-level instruction that makes coding agents read and follow `CLAUDE.md` before repository work.

**Architecture:** Keep `CLAUDE.md` as the single source of truth. `AGENTS.md` contains only a bootstrap instruction and does not duplicate project guidance.

**Tech Stack:** Markdown, Git

---

## File Structure

- Create `AGENTS.md`: direct repository agents to the existing guidance.

### Task 1: Add agent bootstrap guidance

**Files:**
- Create: `AGENTS.md`

- [ ] **Step 1: Verify the bootstrap file is currently absent**

Run:

```bash
test -f AGENTS.md
```

Expected: exit code 1 because `AGENTS.md` does not exist.

- [ ] **Step 2: Create the minimal bootstrap file**

Create `AGENTS.md` with exactly:

```markdown
# AGENTS.md

Before working in this repository, read `CLAUDE.md` completely and follow its instructions.
```

- [ ] **Step 3: Verify the content and scope**

Run:

```bash
test -f AGENTS.md
rg -n '^Before working in this repository, read `CLAUDE\.md` completely and follow its instructions\.$' AGENTS.md
test "$(wc -l < AGENTS.md | tr -d ' ')" = "3"
git diff --check
```

Expected: every command exits 0; `rg` prints the instruction on line 3; the file contains only three lines.

- [ ] **Step 4: Commit the bootstrap guidance**

```bash
git add AGENTS.md
git commit --no-gpg-sign -m "docs: direct agents to repository guidance" -m "Co-Authored-By: Codex <noreply@openai.com>"
```
