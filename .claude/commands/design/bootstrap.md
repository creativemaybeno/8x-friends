---
description: One-time setup — create your own Claude Design project and seed it from the repo
argument-hint: "[handle]"
allowed-tools: Bash(node tools/design/sync.mjs:*), Bash(git config:*), Bash(mkdir:*), Bash(rm:*), Write, Read, Edit, mcp__claude-design__create_project, mcp__claude-design__list_projects, mcp__claude-design__get_project, mcp__claude-design__create_support_js, mcp__claude-design__write_files, mcp__claude-design__list_files
---

Run this **once per person**. We are on separate Claude accounts with no shared
organisation, so a Claude Design project cannot be shared between us — each of us
owns a private project holding the same design files, and Git is what joins them.
This command creates your copy and registers it in `design/sync.json`.

Handle to register under (optional): $ARGUMENTS — defaults to your
`git config user.name`.

## Steps

1. Check whether you already have one:

   ```
   node tools/design/sync.mjs doctor
   ```

   If a project already resolves for you, stop and say so — bootstrapping twice
   creates an orphan project.

2. Determine the handle: `$ARGUMENTS` if given, else `git config user.name`.

3. `mcp__claude-design__list_projects`. If a project of the right name already
   exists on this account (e.g. you created it in the UI before setting the repo
   up), offer to adopt it rather than creating a duplicate.

4. Otherwise `mcp__claude-design__create_project` with the `name` field from any
   existing entry in `design/sync.json` (keep the names identical across our
   projects — it makes screenshots and links unambiguous). Note the returned
   `project_id` and `url`.

5. Register it in `design/sync.json`: rename the `teammate` placeholder key to the
   handle from step 2, and fill in `projectId`, `url` and `git` (the exact
   `git config user.name` output). Leave every other entry untouched — the other
   person's project id must survive this edit.

6. Verify with `node tools/design/sync.mjs doctor` — it should now resolve you.

7. Seed the new project:

   a. `mcp__claude-design__create_support_js` for the project (the Design
      Components runtime; required before any `.dc.html` will render).

   b. Then run the `/design:push` flow for every mirrored file. Since the project
      is empty, every path is a create: pass `if_match: "0"` to assert the file
      does not exist yet, and `record` each returned etag.

8. Report the project URL and remind the user to commit the `design/sync.json`
   change so the other person sees where your project lives:

   ```
   git add design/sync.json && git commit -m "design: register <handle>'s Claude Design project"
   ```

## Notes

- `design/.sync/` (etags) is gitignored on purpose: etags are per-project, so
  yours are meaningless to your teammate.
- If `design/files/` is empty because nobody has pulled yet, do step 7 the other
  way round: run `/design:pull` on the account that *does* have the designs,
  commit, and let the other person pull the Git commit and then bootstrap.
