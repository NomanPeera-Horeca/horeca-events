# Agent brief — Horeca Events repo

## ⚠️ admin.html deploys from a DIFFERENT repo

**Render serves `horeca-admin.onrender.com` from
`github.com/NomanPeera-Horeca/horeca-admin`, NOT from this repo.**

The file on that side is named `index.html`, not `admin.html`. The
`render.yaml` in this repo is a stale blueprint and is **ignored** by
Render's dashboard.

Any change to `admin.html` here must be synced with:

```bash
./scripts/sync-admin-to-render.sh "commit message"
```

That script copies `admin.html` → `../Horeca_Admin/index.html`, commits
and pushes the sibling repo. Render auto-deploys within ~60s.

Do not assume `git push` from this repo updates the admin site. See
`.cursor/rules/admin-html-deploy.mdc` for the full rationale.

## Repo layout

| Path / repo | Role | Deploys to |
|---|---|---|
| `/Users/nomanpeera/Downloads/Horeca_Events` · `horeca-events` | source of truth; events site HTML; Supabase functions/migrations | `events.thehorecastore.com` (AWS Amplify) |
| `/Users/nomanpeera/Downloads/Horeca_Admin` · `horeca-admin` | thin wrapper around a single `index.html` copied from here | `horeca-admin.onrender.com` (Render) |

## Supabase

- Project ref: `hgvfixbopldwptnfpxwc` (already linked via `supabase link`).
- Run SQL with `supabase db query --linked -f path/to/file.sql`.
- Deploy functions with `supabase functions deploy <name> --no-verify-jwt`.
- Set secrets with `supabase secrets set KEY=value`.

## Before you edit admin.html — checklist

1. [ ] Read `.cursor/rules/admin-html-deploy.mdc`.
2. [ ] Make the change in `admin.html` here.
3. [ ] Commit + push in this repo (source of truth).
4. [ ] Run `./scripts/sync-admin-to-render.sh "<msg>"`.
5. [ ] Verify live:
   ```bash
   curl -sS "https://horeca-admin.onrender.com/?cb=$(date +%s)" | wc -c
   ```
   Should match byte-count of `admin.html`.
