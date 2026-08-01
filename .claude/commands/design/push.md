---
description: Push design/files/ up into your own Claude Design project
argument-hint: "[path or --all]"
allowed-tools: Bash(node tools/design/sync.mjs:*), Bash(mkdir:*), Bash(rm:*), Bash(git status:*), Write, Read, mcp__claude-design__list_files, mcp__claude-design__write_files, mcp__claude-design__create_support_js, mcp__claude-design__render_preview
---

Upload the Git mirror (`design/files/`) **into your own Claude Design project**,
so a teammate's committed design changes become editable in your Claude Design UI.

Argument (optional): $ARGUMENTS — a single project-relative path, or `--all` /
nothing for every changed file.

## Non-negotiable rules

1. **Send the file exactly as it is on disk.** `write_files` takes raw content in
   `data` — *not* entity-escaped. Read the local file and pass its bytes through
   unchanged. No reformatting, no truncation, no `...`.
2. **Always pass `if_match`** when the path already exists in sync state, using
   the recorded `etag`. Omitting it is last-write-wins and will silently
   overwrite an edit you made in the Claude Design UI ten minutes ago.
3. **Never `record` a path whose write did not return an etag.**

## Steps

1. `node tools/design/sync.mjs target --json` → the `project_id`.

2. `mcp__claude-design__list_files` (`depth: -1`), write verbatim to
   `design/.staging/remote.json`, then:

   ```
   node tools/design/sync.mjs plan --remote design/.staging/remote.json --json
   ```

3. If `conflict` is non-empty: **stop** and ask the user. A conflict means the
   same file changed both in the mirror and in your Claude Design project.

4. Make sure the Design Components runtime exists before any `.dc.html` lands —
   every `.dc.html` loads it via `<script src="./support.js">`. If `support.js`
   is absent from the remote listing (or you are pushing a `.dc.html` for the
   first time), call `mcp__claude-design__create_support_js` with the project id.
   It is server-provided; never mirror or hand-write it.

5. For each entry in `push` (or just the named path):

   a. `Read` the local file `design/files/<path>` in full.

   b. `mcp__claude-design__write_files` with:
      - `path`: the project-relative path (identical to the mirror path)
      - `data`: the file content, verbatim
      - `if_match`: the `etag` from the plan entry, when present

      The first write to a project prompts once for a standing write grant —
      that is expected; ask the user to approve it.

   c. On `{status: "conflict"}`: stop for that path, report it, and suggest
      `/design:pull` for that file first. Do not retry without `if_match`.

   d. On success, take the new etag from the response's `etags` map:

      ```
      node tools/design/sync.mjs record --path "<path>" --etag <new-etag>
      ```

6. For each entry in `deleteRemote`, confirm with the user first, then
   `mcp__claude-design__delete_files` and `sync.mjs forget --path "<path>"`.

7. `rm -rf design/.staging`

8. Report the `url` from the last `write_files` response so the user can open the
   design and **eyeball it**. The byte-size check guards the pull direction; for
   the push direction the rendered design in Claude Design is the check.

## Notes

- Quote paths — they contain spaces.
- If you are pushing into a brand-new, empty project, use `/design:bootstrap`
  instead: it creates the project and registers it in `design/sync.json`.
