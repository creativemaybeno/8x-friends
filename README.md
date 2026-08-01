# 8x Friends

Hackathon monorepo: **an offline-first social app**. Flutter client, Supabase
backend, and the Claude Design source files all live here together.

```
8x-hack/
├── specs/               what we're building and why       → specs/README.md
├── design/              Claude Design files, mirrored into Git  → design/README.md
├── app/                 Flutter client (iOS + Android)
├── supabase/            Postgres migrations, edge functions, local stack config
├── tools/design/        the sync engine behind the /design:* commands
├── docs/                working notes
├── .claude/commands/    slash commands shared by everyone working in this repo
└── Makefile             make help
```

**Start with [specs/](specs/README.md)** — the product brief, scope, features,
data model and open questions, reconstructed from the Claude Design project and
the prompts that produced it. Every claim there is tagged with where it came
from, so you can tell a decision from a guess.

## Quickstart

```bash
git clone https://github.com/creativemaybeno/8x-hack.git && cd 8x-hack
make setup                # LFS, flutter pub get, dart_define.json from the template
make db-start             # local Supabase (needs Docker)
# paste the API URL + key it prints into app/dart_define.json
make app-run
```

Then, once per person, in Claude Code:

```
/design:bootstrap         # creates *your* Claude Design project and seeds it
```

## Working together

We are two people on two personal Claude subscriptions, which means two separate
organisations — so a Claude Design project **cannot** be shared between us. Git is.

- Each of us owns a private Claude Design project holding the same files.
- `design/files/` in this repo is the source of truth joining them.
- `/design:pull` brings your Claude Design edits into Git; `/design:push` sends
  Git's version into your Claude Design project.

Full model, conflict handling and caveats: **[design/README.md](design/README.md)**.

### Branches

| Work        | Branch                            | Why                                                          |
| ----------- | --------------------------------- | ------------------------------------------------------------ |
| **Designs** | straight to `main`, small commits | Both of us need them immediately; they never touch app code.  |
| **Code**    | `feat/<thing>` → PR → `main`      | Normal review flow; long-lived branches are fine.             |

Design commits and code commits touch disjoint directories, so a code branch can
sit open for a day and still rebase onto design commits cleanly. The reverse is
not true *within* `design/files/`: those files do not merge (see design/README.md),
so **claim a design file in chat before you edit it.**

## Commands

```
make help                 # all targets
make check                # analyze + test + design doctor (no Docker needed)
```

| Task                       | Command                          |
| -------------------------- | -------------------------------- |
| Run the app                | `make app-run`                   |
| Analyze + test             | `make app-test`                  |
| Format & auto-fix Dart     | `make app-fix`                   |
| Start / stop local DB      | `make db-start` / `make db-stop` |
| New migration from changes | `make db-diff NAME=add_posts`    |
| Reset DB to migrations     | `make db-reset`                  |
| Design sync health         | `make design-doctor`             |

## Configuration & secrets

Nothing secret is committed. `app/dart_define.example.json` is the template; your
real values go in `app/dart_define.json` (gitignored). The Supabase
publishable/anon key is a public, RLS-scoped credential and belongs in the client
build; the **service-role key never does** — it lives in Supabase Edge Function
secrets.

## Git LFS

Configured in `.gitattributes`, initialised by `make setup`. Large binaries
(video, audio, fonts, `.psd`/`.sketch`/`.fig`, archives, app bundles) and raster
images under `design/`, `app/assets/` and `docs/assets/` go to LFS.

Two deliberate exceptions:

- Platform launcher icons under `app/ios/` and `app/android/` stay ordinary Git
  blobs, so a clone on a machine without `git-lfs` still builds.
- Design `.dc.html` files stay out of LFS — they are text and we want them
  diffable. They are marked `-text` so Git never rewrites a byte, which is what
  keeps the sync's size verification meaningful.

## Stack

|              |                        |
| ------------ | ---------------------- |
| Flutter      | 3.44.4 (Dart 3.12.2)   |
| Supabase CLI | 2.109.1, Postgres 17   |
| Client SDK   | `supabase_flutter` ^2.16.0 |
