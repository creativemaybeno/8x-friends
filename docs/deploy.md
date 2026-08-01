# Deploy the backend (≈5 minutes)

Zero to a live Supabase project for 8x Friends. Supabase CLI **2.109.1**.

## 1. Prerequisites

```bash
brew install supabase/tap/supabase   # or see supabase.com/docs/guides/cli
supabase login                       # or: export SUPABASE_ACCESS_TOKEN=sbp_...
```

No Docker needed — nothing runs locally.

## 2. One command

```bash
export SUPABASE_DB_PASSWORD='pick-a-strong-password'
make cloud-up          # == ./scripts/cloud-up.sh
```

This creates the project `8x-friends` in `eu-central-1`, links it, pushes
`supabase/migrations/`, pushes `supabase/config.toml`, and writes
`app/dart_define.json` with `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`.
That file is gitignored — never commit it.

Optional env overrides:

| Var                   | Effect                                            |
| --------------------- | ------------------------------------------------- |
| `SUPABASE_ORG_ID`     | Org to create in (default: your first org)        |
| `SUPABASE_DB_PASSWORD`| Required unless `PROJECT_REF` is set              |
| `PROJECT_REF`         | Skip create; link + push to an existing project   |
| `REGION`              | Default `eu-central-1`                            |

Re-running is safe: if `supabase/.temp/project-ref` exists it re-uses it.

## 3. Run the app

```bash
make cloud-run         # flutter run --dart-define-from-file=dart_define.json
```

## Manual steps: none

`supabase config push` exists in CLI 2.109.1 and **does** apply
`[auth] enable_anonymous_sign_ins = true` from `supabase/config.toml`.

**Verified end to end** against a live free-tier project on 2026-08-01:
after `supabase config push`, an anonymous signup returns an access token:

```sh
curl -s -X POST "$SUPABASE_URL/auth/v1/signup" \
  -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
  -H "Content-Type: application/json" -d '{}'
# -> {"access_token":"eyJ...", ...}
```

Use that curl as the smoke test. Only if it returns
`anonymous_provider_disabled` do you need the dashboard fallback:

> Dashboard → your project → **Authentication → Sign In / Providers →
> Anonymous sign-ins** → enable → Save.

### Note on `db push` output

`db push` applies the migration and then tries to cache a schema catalog via
edge-runtime. That second step can fail noisily with
`Failed to read certificate file ... pgdelta-target-ca.crt`. **This is
cosmetic** — the migration is already applied. Confirm with
`supabase migration list`; the row should show the same timestamp under both
`local` and `remote`.

## Do not seed

Leave the remote DB empty. `supabase/seed.sql` stays empty; demo data is
inserted client-side on first launch.

## UNVERIFIED CLI details

These were not confirmed against `--help` in this environment; adjust if the
CLI complains:

- `supabase orgs list --output json` field name `id` for the org ref.
- `supabase projects list --output json` field names `id` / `name`.
- `supabase projects create --org-id --db-password --region` — flags read from
  `--help`, but creating a project was never executed here (we linked to an
  existing one instead).

Verified by actually running them against a live project:
`link --project-ref`, `db push` (and `--dry-run`), `migration list`,
`projects api-keys --project-ref`, `config push`.

`projects api-keys` returns a `keys` array; take the entry whose `api_key`
starts with `sb_publishable_` (there is also a legacy `anon` JWT — either works,
`Env` accepts both, but prefer the publishable one). **Never** take
`sb_secret_*` or `service_role`.
