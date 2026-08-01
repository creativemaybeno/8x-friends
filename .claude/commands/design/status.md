---
description: Diff design/files/ against your own Claude Design project
argument-hint: "[--handle <name>]"
allowed-tools: Bash(node tools/design/sync.mjs:*), Bash(mkdir:*), Bash(rm:*), Write, Read, mcp__claude-design__list_files, mcp__claude-design__get_project
---

Show what differs between the Git mirror (`design/files/`) and **your own** Claude
Design project. Read-only — never writes to either side.

Extra arguments: $ARGUMENTS

## Steps

1. Resolve the target project:

   ```
   node tools/design/sync.mjs target --json
   ```

   If this fails, run `node tools/design/sync.mjs doctor` and report what it says
   instead of guessing a project id.

2. Call `mcp__claude-design__list_files` with that `project_id` and `depth: -1`.

3. Write the returned JSON array **verbatim** to `design/.staging/remote.json`.

4. Run the three-way diff and report it:

   ```
   node tools/design/sync.mjs plan --remote design/.staging/remote.json
   ```

5. `rm -rf design/.staging`

## Reporting

Summarise for the user in this order, and stop after the summary:

- **CONFLICT** first, if any — those need a human decision and block both
  `/design:pull` and `/design:push` for the affected paths.
- **PULL** — the other side of *your* project moved (you edited in the Claude
  Design UI); run `/design:pull`.
- **PUSH** — the mirror moved (you pulled a teammate's commit, or edited the
  files locally); run `/design:push`.
- Also mention the local Git state: `git status --short design/` and whether the
  branch is behind `origin/main`, since a teammate's design commit only reaches
  your Claude Design project after `git pull` **then** `/design:push`.
