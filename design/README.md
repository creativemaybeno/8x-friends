# Designs

Claude Design files for **8x Friends**, mirrored into Git so two people on two
separate Claude accounts can work on the same designs.

## Why this is set up the way it is

A Claude Design project can only be shared inside one organisation — `add_member`
requires the target account to already belong to the project's org, and link
sharing tops out at `scope: org`. Two personal Claude subscriptions are two
different orgs, so **there is no way to put both of us in one project.**

So we don't try. Each of us owns a *private* Claude Design project containing the
same files, and Git is the only thing that joins them:

```
   ┌──────────────────────────┐                  ┌──────────────────────────┐
   │  Claude Design project   │                  │  Claude Design project   │
   │  (account A)             │                  │  (account B)             │
   └───────────▲──────────────┘                  └──────────────▲───────────┘
   /design:pull│ /design:push                     /design:pull  │ /design:push
   ┌───────────▼──────────────┐   git push/pull  ┌──────────────▼───────────┐
   │  design/files/  (repo A) │◄────────────────►│  design/files/  (repo B) │
   └──────────────────────────┘                  └──────────────────────────┘
```

`design/files/` is the source of truth. Each Claude Design project is a personal
working copy of it — like a checkout, not like a branch.

## Layout

| Path                             | What                                                                 |
| -------------------------------- | -------------------------------------------------------------------- |
| `design/files/`                  | Byte-for-byte mirror of a Claude Design project root. Committed.      |
| `design/assets/`                 | Large binaries (video, fonts, source files). Git LFS.                 |
| `design/sync.json`               | Which Claude Design project belongs to whom. Committed.               |
| `design/target.local.json`       | Optional per-user override of the above. **Gitignored.**              |
| `design/.sync/<projectId>.json`  | Last-synced etag + sha256 per file. **Gitignored** — etags are per-project. |
| `design/.staging/`               | Scratch space during a pull. **Gitignored**, deleted after each run.  |
| `tools/design/sync.mjs`          | The diff/decode/verify engine behind the slash commands.              |

## Commands

Run these from Claude Code, in the repo root. Each of them acts on **your own**
Claude Design project — resolved from your `git config user.name` via
`design/sync.json`, so there is nothing to configure.

| Command             | Direction                        |
| ------------------- | -------------------------------- |
| `/design:bootstrap` | one-time: create *your* project   |
| `/design:status`    | read-only diff, both directions   |
| `/design:pull`      | Claude Design → `design/files/`   |
| `/design:push`      | `design/files/` → Claude Design   |

Plus the plumbing directly, when you want it:

```bash
node tools/design/sync.mjs doctor     # is everything wired up?
node tools/design/sync.mjs target     # which project am I pointed at?
node tools/design/sync.mjs plan       # what changed locally since my last sync?
node tools/design/sync.mjs manifest   # sha256 + size of every mirrored file
```

## Daily loop

**You changed a design in the Claude Design UI:**

```
/design:pull
git add design/ && git commit -m "design: <what changed>" && git push
```

**Your teammate pushed a design change:**

```
git pull
/design:push          # only now does it show up in *your* Claude Design project
```

That second step is the one people forget. `git pull` updates the mirror; it does
not touch Claude Design. Nothing reaches your design canvas until you push it there.

## Conflicts

Two kinds, and they are handled differently.

**Git conflict** (both of you committed a change to the same design file).
`.dc.html` files are tens of thousands of characters with very long lines — a
textual three-way merge produces garbage that still parses. Do **not** hand-merge
them. Pick a side wholesale:

```bash
git checkout --ours   "design/files/8x Friends v2 Social.dc.html"   # keep mine
git checkout --theirs "design/files/8x Friends v2 Social.dc.html"   # keep theirs
git add design/ && git commit
```

then `/design:push` and re-apply the lost edit in the Claude Design UI. Which is
why the real rule is: **one owner per design file at a time.** Say in chat which
file you're taking. It costs five seconds and saves a re-do.

**Sync conflict** (a file changed both in the mirror and in your Claude Design
project since your last sync). `plan` reports it under `CONFLICT` and both
`/design:pull` and `/design:push` refuse to touch that path. Decide which side
wins, then run the matching command for that single file.

## What is deliberately not mirrored

Configured in `design/sync.json`:

- **`support.js`** — the ~69 KB Design Components runtime that every `.dc.html`
  loads. The server hands out an identical, current copy via `create_support_js`,
  so mirroring it would only add noise and go stale. `/design:push` and
  `/design:bootstrap` create it in the target project automatically.
- **`.thumbnail`** — a server-rendered project preview that changes on every
  edit. Mirroring it would mean a conflict on every single sync.

## The one real caveat

The Claude Design API has no local-file transport: `read_file` returns
entity-escaped text and `write_files` only takes inline `data`. So in principle
every transfer passes **through the agent's context** — which costs tokens
(roughly 2× file size) and is the one place a mirror can silently corrupt. That
is why `plan` is etag-driven: steady state only moves files that actually changed.

**Pulling has a way around it.** When a tool result is too large for the context
window, the harness spills it to a file and hands the agent the path. So asking
for a whole large design in one `read_file` makes the payload go remote → disk →
`sync.mjs extract` → `decode`, and the agent never transcribes a byte.
`/design:pull` calls this route A and always tries it first. Both of the
`.dc.html` designs here came in that way.

For anything small enough to land inline, the agent *is* the transport, so the
pull path refuses to trust it: the payload is staged *still escaped* (never
un-escaped by hand — `sync.mjs decode` does that in one pass), and the decoded
byte length is checked against the `size` the server reported before anything is
recorded as synced. A mismatch aborts and leaves sync state untouched, so the
file just comes up again on the next pull.

Pushing has no equivalent server-side checksum, so the check there is your eyes:
`/design:push` prints the project URL — open it and look at the design before you
call it done.
