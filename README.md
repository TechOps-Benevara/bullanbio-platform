# Bullan Bio Digital Platform

Business-operations platform for **Bullan Bio**, a medical-consumables brand operated by **Benevara Pte Ltd** (Singapore · UEN 202426130K). Serves dealers across six Southeast-Asian markets (SG, MY, TH, PH, VN, ID) from a single login at **bullanbio.com**.

> **Confidential — Benevara Pte Ltd internal repository.** Not for public distribution.

---

## What this is

One login that routes users by role into three areas:

- **Admin Portal** — Benevara's internal control room (dealers, products, orders, regulations).
- **Dealer Portal** — distributors and independent reps browse the catalogue, place orders, track shipments, download invoices.
- **Regulations Library** — shared, searchable repository of registration, compliance, clinical, and import documents per market.

Full specifications live in the SharePoint **Digital Platform** folder (TECH-01…05, FEAT-01/02, MAN-01). Read **TECH-REVIEW-01** (pre-go-live architecture review) before launch.

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Next.js 14 (App Router) · TypeScript · Tailwind CSS |
| Backend | Next.js API routes (`app/api/*`) |
| Auth | Clerk (SSO + email/password, role management) |
| Database | Supabase (PostgreSQL 15) with Row-Level Security |
| Storage | Supabase Storage (`kyb-documents` private · `regulations`) |
| Hosting | Vercel (CI/CD on push) |
| Validation | Zod · webhook verification via svix |

> Code is produced as specifications by Claude (technical author) and implemented by Aldo (lead developer).

---

## Getting started

> The Next.js application has not been scaffolded yet — this repository currently holds project hygiene only (this README, `.gitignore`, `.gitattributes`, `.env.example`, `CLAUDE.md`, and a `docs/` folder with `CONTRIBUTING.md` and `DEVELOPMENT_ROADMAP.md`). The steps below are the intended setup once scaffolding begins.

```bash
# 1. Install dependencies (after the Next.js app is scaffolded)
npm install

# 2. Configure environment
cp .env.example .env.local
#    then fill in the values — see .env.example for where each comes from

# 3. Run locally
npm run dev          # http://localhost:3000
```

Required environment variables are documented in [`.env.example`](./.env.example). The app validates them on startup and refuses to start if any required one is missing.

---

## Environments

| Environment | Branch | URL | Supabase project |
|---|---|---|---|
| Production | `main` | https://bullanbio.com | bullanbio-prod |
| Staging | `develop` | https://staging.bullanbio.com | bullanbio-staging |
| Local | feature branches | http://localhost:3000 | bullanbio-dev |

Never use real dealer or order data in local or staging.

---

## Branching & deployment

See [`CONTRIBUTING.md`](./docs/CONTRIBUTING.md). In short: `main` = production, `develop` = staging, `feature/*` = work in progress. Vercel auto-deploys on push. Do not push directly to `main` without going through `develop` first.

---

## Repository structure (planned)

```
bullanbio-platform/
├── src/
│   ├── app/                # App Router — pages + api/ (auth, dealers, webhooks)
│   ├── lib/                # env, supabase, rate-limit, encryption, utils
│   ├── schemas/            # Zod validation schemas
│   ├── components/         # ui/, auth/, layout/
│   ├── middleware.ts       # Clerk route protection + security headers
│   └── __tests__/          # Jest unit tests
├── e2e/                    # Playwright tests
├── supabase/migrations/    # 0001_schema.sql, 0002_rls.sql
├── docs/                   # roadmap, CONTRIBUTING, RBAC, DECISIONS, specs/
├── public/
├── .env.example · .nvmrc · CLAUDE.md · README.md
└── (config: package.json · tsconfig.json · next.config.* · tailwind.config.ts)
```

---

## Security notes

- Passwords live only in Clerk — never store them in Supabase.
- Tenant isolation is enforced by Supabase RLS. See **TECH-REVIEW-01 finding F1** before relying on it — the service-role key bypasses RLS, so the isolation model must be settled.
- NRIC / passport numbers are encrypted at rest (`ENCRYPTION_KEY`).
- Do not modify security logic (rate limiting, signature verification, encryption) without discussing with Jessica / Claude first.
