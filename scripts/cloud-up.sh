#!/usr/bin/env bash
# Provision (or re-use) the remote Supabase project and write app/dart_define.json.
# Idempotent: safe to re-run. Set PROJECT_REF to skip create+link.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_NAME="${PROJECT_NAME:-8x-friends}"
REGION="${REGION:-eu-central-1}"
PROJECT_REF="${PROJECT_REF:-}"

# ── Auth ─────────────────────────────────────────────────────────────────────
if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  if ! supabase projects list >/dev/null 2>&1; then
    echo "Not logged in. Run 'supabase login' or export SUPABASE_ACCESS_TOKEN." >&2
    exit 1
  fi
fi

# ── Create + link ────────────────────────────────────────────────────────────
if [[ -z "$PROJECT_REF" && -f supabase/.temp/project-ref ]]; then
  PROJECT_REF="$(cat supabase/.temp/project-ref)"
  echo "Re-using linked project ref from supabase/.temp/project-ref."
fi

if [[ -z "$PROJECT_REF" ]]; then
  : "${SUPABASE_DB_PASSWORD:?set SUPABASE_DB_PASSWORD to a strong password}"
  ORG_ID="${SUPABASE_ORG_ID:-}"
  if [[ -z "$ORG_ID" ]]; then
    ORG_ID="$(supabase orgs list --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')"
    echo "Using first organization: $ORG_ID"
  fi

  echo "Creating project $PROJECT_NAME in $REGION ..."
  supabase projects create "$PROJECT_NAME" \
    --org-id "$ORG_ID" \
    --db-password "$SUPABASE_DB_PASSWORD" \
    --region "$REGION" >/dev/null

  # Resolve the ref by name (create does not print a machine-readable ref).
  PROJECT_REF="$(supabase projects list --output json \
    | python3 -c 'import json,sys,os; n=os.environ["PROJECT_NAME"]; print(next(p["id"] for p in json.load(sys.stdin) if p["name"]==n))')"
fi
export PROJECT_REF
echo "Project ref: $PROJECT_REF"

echo "Linking ..."
supabase link --project-ref "$PROJECT_REF" ${SUPABASE_DB_PASSWORD:+--password "$SUPABASE_DB_PASSWORD"} >/dev/null

# ── Schema ───────────────────────────────────────────────────────────────────
echo "Pushing migrations ..."
supabase db push --yes

# ── Auth config (anonymous sign-ins) ─────────────────────────────────────────
echo "Pushing config.toml ..."
supabase config push --project-ref "$PROJECT_REF" --yes \
  || echo "config push failed — toggle Authentication > Sign In / Providers > Anonymous sign-ins in the dashboard." >&2

# ── Keys → app/dart_define.json ──────────────────────────────────────────────
SUPABASE_URL="https://${PROJECT_REF}.supabase.co"
PUBLISHABLE_KEY="$(supabase projects api-keys --project-ref "$PROJECT_REF" --output json \
  | python3 -c '
import json,sys
keys = json.load(sys.stdin)
def pick(*names):
    for n in names:
        for k in keys:
            if k.get("name") == n:
                return k.get("api_key")
    for k in keys:
        v = k.get("api_key") or ""
        if v.startswith("sb_publishable_"):
            return v
    return ""
print(pick("publishable", "anon"))')"

if [[ -z "$PUBLISHABLE_KEY" ]]; then
  echo "Could not resolve a publishable/anon key." >&2
  exit 1
fi

umask 077
python3 - "$SUPABASE_URL" "$PUBLISHABLE_KEY" <<'PY'
import json, sys
url, key = sys.argv[1], sys.argv[2]
with open("app/dart_define.json", "w") as f:
    json.dump({"SUPABASE_URL": url, "SUPABASE_PUBLISHABLE_KEY": key}, f, indent=2)
    f.write("\n")
PY

echo "Wrote app/dart_define.json (gitignored). URL: $SUPABASE_URL"
echo "Done."
