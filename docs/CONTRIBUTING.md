# Contributing — Bullan Bio Platform

Internal working agreement for this repository. Keep it simple; the team is small.

## Branch strategy

| Branch | Purpose | Deploys to |
|---|---|---|
| `main` | Production. Always deployable. | bullanbio.com |
| `develop` | Integration / staging. | staging.bullanbio.com |
| `feature/<name>` | One feature or fix at a time. | Vercel preview |

- `develop` is the active development branch; `main` is the release branch (always reflects production).
- Branch off `develop` for new work: `git checkout -b feature/dealer-registration`. Open a pull request into `develop`. Test on the staging preview.
- **Promote `develop` → `main` only via a Pull Request, and only when the work is stable AND the end-to-end (Playwright) tests pass**, plus the sprint review sign-off from Benny + Jessica.
- **Never commit or push directly to `main`.** It only ever changes through a reviewed, E2E-passing PR from `develop`.

## Commit messages

Use a short prefix so history is scannable:

```
feat: add dealer registration form
fix:  correct SSO button on login page
docs: update README env var list
test: add Jest coverage for register route
chore: bump dependencies
```

## Before you open a PR

- `npm run build` passes (no TypeScript errors).
- Tests pass: `npm test` (Jest) and `npx playwright test` (E2E) where relevant.
- No secrets committed — `.env.local` stays local. Check `git status` before committing.

## Do not change without discussion

Security-critical logic must be reviewed before changes: rate limiting, webhook
signature verification, encryption, and Supabase RLS policies. Raise with Jessica
(Project Manager), who coordinates with Claude. See **TECH-REVIEW-01** for the open
architecture findings (especially F1–F3) that affect these areas.

## Environment variables

Documented in [`.env.example`](../.env.example). When you add a new variable, add it
there too (with a blank value and a comment) and set it in Vercel for each environment.
