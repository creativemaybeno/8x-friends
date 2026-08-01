# 8x Friends

Hackathon monorepo: **an offline-first social app**. Flutter client and Supabase
backend. The designs live in Claude Design, not in this repo.

```
8x-hack/
├── specs/               what we're building and why       → specs/README.md
├── app/                 Flutter client (iOS + Android)
├── supabase/            Postgres migrations, edge functions, local stack config
├── docs/                working notes
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

## Designs

Both of us work from one shared Claude account, so the Claude Design project is
the single source of truth for designs — read and edit them there directly.
The editable design files are not mirrored into Git; the gallery below is a
committed visual preview for hackathon reviewers.

## App preview

8x Friends helps people notice when a valued relationship is fading, make a
low-friction plan, and see real-world meetups renew their social graph.

<p align="center">
  <img src="docs/assets/screenshots/01-home-relationship-health.png" alt="Relationship health graph showing a fading connection to Yassie" width="30%" />
  <img src="docs/assets/screenshots/06-invitation.png" alt="Invitation from Calvin to meet on Saturday" width="30%" />
  <img src="docs/assets/screenshots/09-add-from-your-circle.png" alt="Adding people from a friend circle to a planned meetup" width="30%" />
</p>
<p align="center">
  <img src="docs/assets/screenshots/13-plan-detail.png" alt="Meetup plan detail for Calvin, Yassie, and Hannan" width="30%" />
  <img src="docs/assets/screenshots/17-connection-renewed.png" alt="Confirmation that a relationship has been renewed after meeting" width="30%" />
  <img src="docs/assets/screenshots/21-consented-connection.png" alt="A newly accepted, neutral social connection" width="30%" />
</p>

The preview illustrates the prototype flow: **notice → invite → gather → meet →
renew**, with consent required before new direct connections are created.

**[8x Friends: Offline Facebook](https://claude.ai/design/p/9783b908-0e28-4a55-89fe-70bd0b95a59e)**

Same account means the same project: **claim a design file in chat before you
edit it**, or you will overwrite each other.

### Branches

Code goes on `feat/<thing>` branches via PR into `main`. Designs are not in Git
at all, so they never collide with a code branch.

## Commands

```
make help                 # all targets
make check                # analyze + test (no Docker needed)
```

| Task                       | Command                          |
| -------------------------- | -------------------------------- |
| Run the app                | `make app-run`                   |
| Analyze + test             | `make app-test`                  |
| Format & auto-fix Dart     | `make app-fix`                   |
| Start / stop local DB      | `make db-start` / `make db-stop` |
| New migration from changes | `make db-diff NAME=add_posts`    |
| Reset DB to migrations     | `make db-reset`                  |

## Configuration & secrets

Nothing secret is committed. `app/dart_define.example.json` is the template; your
real values go in `app/dart_define.json` (gitignored). The Supabase
publishable/anon key is a public, RLS-scoped credential and belongs in the client
build; the **service-role key never does** — it lives in Supabase Edge Function
secrets.

## Git LFS

Configured in `.gitattributes`, initialised by `make setup`. Large binaries
(video, audio, fonts, archives, app bundles) and raster images under
`app/assets/` and `docs/assets/` go to LFS.

One deliberate exception: platform launcher icons under `app/ios/` and
`app/android/` stay ordinary Git blobs, so a clone on a machine without
`git-lfs` still builds.

## Stack

|              |                        |
| ------------ | ---------------------- |
| Flutter      | 3.44.4 (Dart 3.12.2)   |
| Supabase CLI | 2.109.1, Postgres 17   |
| Client SDK   | `supabase_flutter` ^2.16.0 |
