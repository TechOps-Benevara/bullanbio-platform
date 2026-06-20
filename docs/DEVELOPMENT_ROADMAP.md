# Bullan Bio Platform — Development Roadmap

**Guidance for Claude Code (and any engineer) building this codebase.**
Version 1.0 · 20 June 2026 · Owner: Aldo (Lead Developer)

> This roadmap turns the specification documents (TECH-01…05, FEAT-01/02, MAN-01) and the
> pre-go-live review (TECH-REVIEW-01) into an ordered, executable build plan. Follow it
> top to bottom. Do not skip the **Decision Gates** — they prevent expensive rework.

---

## 0. How to use this document

- The work is organised into **Phase 0 (Bootstrap)** followed by **Sprints 1–5**, matching TECH-02.
- Each phase lists: **Objective → Prerequisites → Steps → Key files → Definition of Done → Findings addressed.**
- **Decision Gates** are blocking. The codebase must not grow past a gate until the decision is made and written into TECH-09 (Decision & Build Log).
- The authoritative *what* lives in the spec docs. This roadmap is the *how* and the *order*. Where they disagree, the spec wins — raise the conflict, do not guess.
- **Recommendation:** copy the machine-usable specs into the repo so Claude Code can read them without leaving the codebase — at minimum the database schema (as SQL) and the RBAC permission matrix. Put them under `/docs` and `/supabase/migrations`.

---

## 1. Ground rules (non-negotiable)

These apply to every line of code. Treat them as lint rules for judgement.

1. **Document before code.** Implement from the spec. If a behaviour is not in a spec doc, stop and get it specified — do not invent it.
2. **TypeScript strict mode on.** No `any` without a written reason. Types for DB rows must match TECH-05 exactly.
3. **Environment access only through `src/lib/env.ts`.** Never read `process.env` directly elsewhere. The app must fail fast on a missing required var.
4. **Two Supabase clients, never mixed up** (`src/lib/supabase.ts`):
   - `supabase` (anon key, RLS enforced) — for user-context reads/writes.
   - `supabaseAdmin` (service-role key, **bypasses RLS**) — **server-side API routes only**. Never import it into a client component.
5. **Tenant isolation is law.** See **Decision Gate A (F1)**. Until it is settled, every query that touches tenant data through `supabaseAdmin` MUST include an explicit `.eq('tenant_id', <caller's tenant>)` filter, and that filter must be covered by a test.
6. **Passwords live only in Clerk.** Never store password material in Supabase. User identity = Clerk; user data = Supabase, linked by `clerk_user_id`.
7. **Never weaken security primitives** (rate limiting, webhook signature verification, encryption, RLS policies) without a review recorded in TECH-09. See TECH-REVIEW-01 F1–F4.
8. **Every feature ships with tests.** Unit (Jest) for logic and validation; E2E (Playwright) for each critical user flow. A feature is not done until its tests pass.
9. **Branch + commit discipline.** Work on `feature/<name>` off `develop`; PR into `develop`; promote to `main` only after sprint sign-off. Commit prefixes: `feat:`, `fix:`, `docs:`, `test:`, `chore:`. See `CONTRIBUTING.md`.
10. **No scope creep mid-sprint.** New ideas go to TECH-09 for a future sprint, not into the current branch.
11. **No secrets in git.** `.env.local` stays local. Verify `git status` before every commit.
12. **Pin the stack.** TECH-04 specifies **Next.js 14**, TypeScript 5, Tailwind 3. Do not silently upgrade major versions; a change is a TECH-09 decision.

---

## 2. Target repository layout (canonical)

We use the **`src/` directory** convention. App Router lives at `src/app`. The `@/*` import alias maps to `./src/*`.

```
bullanbio-platform/
├── src/
│   ├── app/
│   │   ├── layout.tsx              # wraps app in <ClerkProvider>
│   │   ├── page.tsx                # login page (Package 2)
│   │   ├── register/page.tsx       # registration (Package 2)
│   │   ├── verify-email/page.tsx
│   │   ├── pending/page.tsx
│   │   ├── deactivated/page.tsx
│   │   ├── forgot-password/page.tsx
│   │   ├── admin/                  # admin portal (Sprints 2–3)
│   │   ├── dealer/                 # dealer portal (Sprints 4–5)
│   │   └── api/                    # API routes (Package 1)
│   │       ├── auth/{location,redirect,resend-verification}/route.ts
│   │       ├── dealers/{register,kyb-upload}/route.ts
│   │       └── webhooks/clerk/route.ts
│   ├── lib/                        # env, supabase, rate-limit, encryption, utils (Packages 1–2)
│   ├── schemas/                    # Zod schemas (Package 1)
│   ├── components/                 # ui/, auth/, layout/ (Package 2)
│   ├── middleware.ts               # Clerk route protection + security headers (Package 1)
│   └── __tests__/                  # Jest unit tests (Package 3)
├── e2e/                            # Playwright tests (Package 4)
├── supabase/migrations/            # SQL migrations (schema + RLS + indexes)
├── docs/                           # in-repo copies of key specs (schema, RBAC matrix)
├── public/
├── .env.example                    # already present — names match src/lib/env.ts
├── .env.local                      # local only, git-ignored
└── (config: package.json, tsconfig.json, next.config.*, tailwind.config.ts, etc.)
```

> **Mapping note for the Sprint 1 packages.** The package READMEs write API routes under `app/api/...`. In our `src/`-dir layout every `app/...` path becomes **`src/app/...`**. The `src/lib`, `src/schemas`, `src/components`, and `src/middleware.ts` paths are already correct as written.

---

## 3. Decision Gates (settle before the dependent code)

| Gate | Finding | Decision required | Blocks |
|---|---|---|---|
| **A** | **F1** | Tenant isolation model: RLS-enforced (queries via Clerk-JWT'd anon client) **or** application-enforced (service-role + mandatory `tenant_id` filters, RLS as backstop). | All RLS policies; every tenant-data feature (Sprints 2–5). |
| **B** | **F2** | How `tenant_id` / `role` / `tenant_role` get into the Clerk session token and stay in sync with `tenant_users`. | Anything reading those claims (middleware authz + all RLS). |
| **C** | **F3** | `regulations` storage bucket: private + signed URLs, or genuinely public. | Regulations upload/download (Sprints 2 & 4). |

**Gate A + B must be resolved during Phase 0**, because the database RLS and the Clerk integration are built there and everything sits on top of them. Resolve C before the regulations feature in Sprint 2.

> Recommended resolution for A+B (confirm against current Supabase + Clerk docs at build time, as these integrations changed in 2025): use **Supabase's native third-party-auth integration with Clerk**, configure the Clerk session token to carry `role`, `tenant_id`, and `tenant_role` claims, pass the Clerk token to the `supabase` client via its `accessToken` option, and write RLS policies that read `auth.jwt() ->> '...'` exactly as TECH-05 specifies. Keep `supabaseAdmin` for trusted server-only operations (registration, webhooks, admin cross-tenant reads).

---

## 4. Phase map

| Phase | Sprint | Goal | Findings woven in |
|---|---|---|---|
| 0 | Sprint 0 (code) | Project scaffolded, config, core libs wired, DB + RLS live, Clerk + roles, observability. | F1, F2, F8, F9 |
| 1 | Sprint 1 | Login, SSO, IP geo, role routing, dealer registration + KYB, approval queue, emails. | F5 (reminders cron) |
| 2 | Sprint 2 | Admin: dashboard, dealer management (Paths A/B/C), products, regulations. | F3 |
| 3 | Sprint 3 | Admin: orders end-to-end, status flow, notifications, AM assignment. | — |
| 4 | Sprint 4 | Dealer portal: register, browse catalogue in local currency, regulations, sub-dealers. | — |
| 5 | Sprint 5 | Dealer portal: order placement, invoice PDF, launch + hardening pass. | F4, F6, F7 |

---

## 5. Phase 0 — Project bootstrap

**Objective.** Go from the hygiene-only repo to a building, deployable Next.js app with the database, auth, and core libraries in place, and the two foundational decisions resolved.

**Prerequisites.** Node 20 LTS, Git, three Supabase projects (dev/staging/prod), a Clerk application, a Vercel account, the GitHub repo online.

### 5.1 Scaffold Next.js 14 (preserve the hygiene files)

Because `create-next-app` refuses to run in a directory containing non-allowlisted files (`.env.example`, `CONTRIBUTING.md`), scaffold into a temporary folder and merge:

```bash
# from the PARENT directory of the repo
npx create-next-app@14 bb-scaffold \
  --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm
```

Then copy these generated items **into** `bullanbio-platform/`, keeping the existing hygiene files:

- `package.json`, `package-lock.json`
- `tsconfig.json`, `next.config.*`, `postcss.config.*`, `tailwind.config.ts`, `.eslintrc.json`
- `next-env.d.ts`
- `src/app/` (layout, page, globals.css), `public/`

**Do not** copy `bb-scaffold/.gitignore` or `bb-scaffold/README.md` — ours already cover Next.js and the project. Delete `bb-scaffold/` afterwards. Run `npm install` and confirm `npm run dev` serves `http://localhost:3000`.

> Confirm `tsconfig.json` has `"paths": { "@/*": ["./src/*"] }`. With `--src-dir` this is the default.

### 5.2 Install dependencies

```bash
# Runtime
npm install @clerk/nextjs @supabase/supabase-js zod svix clsx tailwind-merge

# Observability (F8 — install early so we have error visibility while building)
npm install @sentry/nextjs

# Dev / testing
npm install -D jest jest-environment-jsdom @types/jest ts-jest \
  @testing-library/react @testing-library/jest-dom @testing-library/user-event \
  @playwright/test @axe-core/playwright
npx playwright install chromium
```

> Use the `@clerk/nextjs` major version compatible with Next.js 14. The Sprint 1 `middleware.ts` already uses the modern `clerkMiddleware` / `createRouteMatcher` API (`@clerk/nextjs/server`), so v5+ is required.

### 5.3 Configure Tailwind brand theme (TECH-04)

In `tailwind.config.ts`, extend `theme.extend.colors`:

```ts
colors: {
  background: '#05080F',
  primary:    '#38BDF8',
  secondary:  '#1A3C5E',
  success:    '#0F6E56',
  warning:    '#854F0B',
}
```

### 5.4 Drop in the Sprint 1 core libraries (Package 1 + 2)

Copy these into the layout from §2 and make the app compile around them:

- `src/lib/env.ts`, `src/lib/supabase.ts`, `src/lib/rate-limit.ts`, `src/lib/encryption.ts`, `src/lib/utils.ts`
- `src/schemas/registration.ts`
- `src/middleware.ts`
- `src/components/ui/{button,form-input,skeleton,error-boundary}.tsx`

Set every variable from `.env.example` in `.env.local`. Generate `ENCRYPTION_KEY` with:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```
Back the key up in a password manager **and** Vercel — losing it makes encrypted NRIC/passport data unrecoverable.

### 5.5 Wire Clerk

- Wrap `src/app/layout.tsx` in `<ClerkProvider>`.
- Configure the 10 roles in Clerk (TECH-04): `owner, super_admin, account_manager, finance_manager, tenant_owner, tenant_manager, tenant_staff, individual_dealer, sub_dealer, hospital_user` (`publicMetadata.role`).
- Register the Clerk webhook endpoint `/api/webhooks/clerk` (events: email-verified, user-deleted) and set `CLERK_WEBHOOK_SECRET`.

### 5.6 🔒 Decision Gate A + B (F1, F2) — resolve now

Decide and document the isolation model and the Clerk→Supabase token mechanism (Section 3). Implement the chosen token flow so `auth.jwt()` carries `role`, `tenant_id`, `tenant_role`. **Write the decision into TECH-09 before building the schema.**

### 5.7 Create the database (TECH-05)

Use Supabase migrations under `supabase/migrations/` so schema changes are versioned and replayable across dev/staging/prod.

1. Create the 10 tables **in dependency order** (TECH-05 §2): `tenants → dealer_profiles → tenant_users → products → orders → order_items → invoices → regulations_docs → kyb_documents → tenant_activity_log`.
2. Apply conventions from TECH-05 §5 (UUID PKs, `created_at`/`updated_at` + update trigger, soft deletes, `numeric(12,2)` money storing both local and USD, text + CHECK enums).
3. Add the **RLS policies** exactly as TECH-05 specifies (they depend on Gate A/B being done).
4. Add the **indexes** from TECH-05 §6.
5. Create storage buckets: `kyb-documents` (**private** — admin only), `regulations` (per **Gate C / F3**).
6. Put the schema SQL in the repo (`/docs` or the migration files) so it is reviewable and Claude-Code-readable.

### 5.8 🌏 F9 — confirm Supabase region = Singapore

When creating the three Supabase projects, set the region to **Singapore** for lowest latency to the six SE-Asia markets. Migrating regions later is disruptive — verify now.

### 5.9 Observability (F8)

Initialise `@sentry/nextjs` (client + server) so errors during Sprints 1–5 are visible, not silent. Enable Vercel and Supabase logging.

**Definition of Done (Phase 0).** `npm run build` passes; `npm run dev` serves the login page; all required env vars validate; the 10 tables + RLS + indexes exist in the dev Supabase project; Clerk roles configured; the token carries `role`/`tenant_id`/`tenant_role`; Gate A/B decision recorded in TECH-09; Sentry reporting; repo deploys to Vercel (blank/login page) on push.

---

## 6. Phase 1 — Sprint 1: Login, Authentication & Registration

**Spec:** FEAT-01. **Goal (TECH-02):** Benny logs in and lands on the admin dashboard; a test dealer registers and is approved.

**Objective.** Integrate the four Sprint 1 packages into the scaffolded app and make the full auth + registration journey work live.

**Steps.**
1. Convert `bullanbio_login.html` into the login page (`src/app/page.tsx`, Package 2) — do not alter the approved design without Benny's sign-off.
2. Wire SSO (Google, Microsoft) and email/password via Clerk.
3. IP geolocation on load via `/api/auth/location` (ip-api.com dev; ipinfo.io prod) — silent fail, never blocks login.
4. Role-based routing: Benevara roles → `/admin/dashboard`; active dealer → `/dealer/dashboard`; plus the unverified / pending / inactive / wrong-password states (FEAT-01 §2.4).
5. Registration form (`src/app/register/page.tsx`) — company + individual fields (FEAT-01 §4), KYB upload (`/api/dealers/kyb-upload`), agreement checkbox.
6. Registration API (`/api/dealers/register`) — Zod validation, rate limit, duplicate-email check, Clerk user + `tenants` + `dealer_profiles` + `tenant_users`, **atomic rollback on failure**.
7. Email verification flow (Clerk webhook updates `unverified → pending`); admin pending queue surfaces the registration.
8. Approval → welcome email → password setup → login; rejection flow with reason; forgot-password flow.
9. Configure all 10 Clerk email templates with Bullan Bio branding (FEAT-01 §10).
10. **F5:** add a scheduled job (Vercel Cron or Supabase `pg_cron`) for document reminders (day 3 / day 6) and auto-archive (day 7). These are part of the registration flow and must run.
11. Land the **Jest** (Package 3) and **Playwright** (Package 4) suites; make them green.

**Integration notes — from the Sprint 1 code review (close these while wiring up the packages).**
The four Sprint 1 packages are production-grade and are the source for this phase, but the review found small gaps to close during integration:

1. **`ON DELETE CASCADE` must exist on the schema.** `api/dealers/register/route.ts` rolls back a failed registration by deleting the `tenants` row and relies on the FK cascade to remove the `dealer_profiles` and `tenant_users` rows. `supabase/migrations/0001_schema.sql` defines these cascades — confirm they are applied before testing registration rollback.
2. **Make `ENCRYPTION_KEY` a required env var.** It is not in `src/lib/env.ts`'s required list, and `safeEncrypt()` returns `null` silently on failure — a missing key would store an empty NRIC/passport without error. Add `ENCRYPTION_KEY` to the required list (or fail hard for that field).
3. **Verify the verification email actually sends.** The register route assumes Clerk emails the verification link automatically on backend `createUser` — that is not guaranteed. Confirm the trigger works, and that the `/api/auth/resend-verification` fallback delivers.
4. **F1 / service-role.** The Sprint 1 routes use `supabaseAdmin` (service-role, bypasses RLS) — appropriate for registration and webhooks, but it does not satisfy tenant isolation on read paths. Gate A still governs reads.
5. **F4 rate limiting.** The in-memory limiter is fine for this phase; move it to a shared store before relying on it for brute-force protection (Sprint 5 hardening).

**Definition of Done.** Every item in the FEAT-01 Sprint 1 checklist (37 items) passes on the live site; Jest + Playwright green; reviewed by Benny + Jessica on bullanbio.com; milestone **M2** recorded.

---

## 7. Phase 2 — Sprint 2: Admin — Dealers & Products

**Spec:** FEAT-02 (Sprints 2 sections). **Goal:** Benny can fully manage dealers and products; upload and browse regulations.

**Objective.** Build the admin shell and the dealer + product + regulations management surfaces.

**Steps.**
1. Admin layout: collapsible sidebar, contextual top bar, content area; command palette (Cmd/Ctrl-K). Wrap dashboard sections in `ErrorBoundary`.
2. Role-based dashboards (Owner/Super Admin full; Account Manager scoped; Finance Manager finance-only) with the Intelligence widgets (show the "not enough data yet" state when fewer than 3 orders/product).
3. Dealer list + filters + slide-in detail panel (Profile / Documents / Orders / Activity tabs).
4. Pending approval queue with the four-check gate (email ✓, docs ✓, docs reviewed, agreement) — Approve disabled until all complete; rejection requires a reason.
5. Add Dealer (Path C) and Send Invite (Path B, 7-day expiry) modals.
6. Product catalogue: list, add/edit, SKU uniqueness, hide (active=false), stock fields.
7. Regulations library (admin): upload to Supabase Storage, metadata (country/category/version), search + filter. **Apply Gate C / F3** for bucket access.
8. Account Manager assignment from the dealer panel.
9. Enforce the **permission matrix** (FEAT-02 §8) **server-side in every API route**, not just by hiding UI.

**Definition of Done.** FEAT-02 Sprint 2 checklist passes live; tests green; reviewed by Benny + Jessica; milestone **M3** (in part).

---

## 8. Phase 3 — Sprint 3: Admin — Orders & Full Operations

**Spec:** FEAT-02 (orders) + TECH-05 §4 (status flow). **Goal:** orders managed end-to-end; admin portal fully operational.

**Steps.**
1. Order list (submitted+ only — never expose drafts to Benevara), search/filter/sort, status badges.
2. Order detail panel: read-only line items, internal notes, status update (forward-only, each change requires a note + emails the dealer).
3. Status transitions per TECH-05 §4 / FEAT-02 §5.3: `submitted → confirmed → invoiced → paid → shipped → delivered`, plus `cancelled` (reason required). Stock reserved on confirm, returned on cancel.
4. Internal company-tenant approval flow: staff `draft` → manager/owner `submitted`.
5. Logistics fields (courier + tracking) — manual entry for MVP.
6. Email notifications on every status change.
7. Regulations: tagging, versioning, delete; Account Manager assignment surfaced to dealers.

**Definition of Done.** FEAT-02 Sprint 3 checklist passes live; tests green; reviewed; milestone **M3** complete.

---

## 9. Phase 4 — Sprint 4: Dealer Portal — Register & Browse

**Spec:** TECH-02 Sprint 4. **Goal:** a real dealer registers, is approved, logs in, browses the catalogue in local currency, accesses regulations.

**Steps.**
1. Dealer dashboard (recent orders, announcements, quick links) and account profile page.
2. Product catalogue for dealers with **local-currency display** based on IP detection (USD base × rate; MVP pricing is manual per TECH-01 — no auto-conversion).
3. Regulations library (dealer read-only view): search, filter, download (respecting Gate C).
4. Pending-approval holding screen; deactivated screen.
5. Individual-dealer network: add/manage sub-dealers; network dashboard summarising sub-dealer activity.
6. Show the assigned Account Manager's name and contact.
7. Verify RLS end-to-end: a dealer can never see another tenant's data (write a Playwright test that asserts this against the live policies).

**Definition of Done.** TECH-02 Sprint 4 checklist passes live; cross-tenant isolation test green; reviewed; milestone **M4**.

---

## 10. Phase 5 — Sprint 5: Dealer Portal — Orders, Launch & Hardening

**Spec:** TECH-02 Sprint 5. **Goal:** real dealer places a real order, downloads an invoice; MVP live.

**Steps.**
1. Order placement flow (browse → review → confirm). Individual-dealer orders skip `draft` (created `submitted`); company-staff orders start `draft` and need internal approval.
2. Order confirmation email; dealer order-tracking screen.
3. Invoice PDF download for confirmed+ orders. **F6:** generate invoice numbers via a Postgres sequence / atomic counter (or defer to Xero numbering and record the decision) to avoid collisions.
4. End-to-end testing of the admin and dealer flows; fix all critical bugs.

**Pre-launch hardening pass (do before flipping to production):**
5. **F4** — move rate limiting off the in-memory map to a shared store (Upstash Redis or a Supabase table); or confirm Clerk's own login rate limiting is sufficient and record that.
6. **F7** — enable Supabase backup / point-in-time recovery on the production project; perform and document one test restore.
7. **F3** — confirm the regulations bucket access matches the final spec.
8. Remove all test data; confirm every variable in `.env.example` is set in the production environment (the 8 required ones plus any optional ones in use); confirm RLS on every tenant table in the Supabase dashboard; valid SSL on bullanbio.com; no console errors.
9. Onboard at least 3 real dealers.

**Definition of Done.** TECH-02 Sprint 5 checklist + the TECH-REVIEW-01 go-live checklist pass; Benny signs off readiness; Jessica confirms all sprint checklists; milestone **M5** (MVP live).

---

## 11. Cross-cutting practices

**Testing.** Unit-test validation/logic and utilities (Jest). E2E-test each critical flow (Playwright): login (all roles + error states), registration → verify → pending, route protection / RBAC, and (from Sprint 4) cross-tenant isolation. Keep the Package 3/4 suites green as features land.

**Definition of Done (per feature).** Matches the spec; typed against TECH-05; unit + relevant E2E tests pass; `npm run build` clean; RLS verified for any tenant data; permission matrix enforced server-side; PR reviewed; deployed to staging (`develop`); included in the sprint review.

**Deployment.** Vercel auto-deploys: `develop → staging.bullanbio.com`, `main → bullanbio.com`. Set env vars per environment. Never push straight to `main`. Every sprint ends with a live review by Benny + Jessica before the next begins.

**Migrations.** All schema changes go through `supabase/migrations/` and are applied dev → staging → prod. Never hand-edit production tables.

---

## 12. Architecture findings tracker (TECH-REVIEW-01)

| Finding | Severity | Resolved in | Status |
|---|---|---|---|
| F1 — RLS vs service-role isolation model | High | Phase 0 · Gate A | ☐ |
| F2 — Clerk↔Supabase claim sync | High | Phase 0 · Gate B | ☐ |
| F9 — Supabase region = Singapore | Low | Phase 0 · §5.8 | ☐ |
| F8 — Observability / error tracking | Medium | Phase 0 · §5.9 | ☐ |
| F5 — Reminder / auto-archive cron | High | Sprint 1 · step 10 | ☐ |
| F3 — Regulations bucket access | High | Phase 0 Gate C / Sprint 2 | ☐ |
| F4 — Rate limiting (shared store) | Medium | Sprint 5 hardening | ☐ |
| F6 — Invoice number concurrency | Medium | Sprint 5 · step 3 | ☐ |
| F7 — Backup / DR | High | Sprint 5 hardening | ☐ |
| F10 — VND/IDR money precision | Low | Phase 0 (schema review) | ☐ |
| F11 — Payment webhook idempotency | Low | Post-MVP (finance module) | ☐ |

---

*End of DEVELOPMENT_ROADMAP.md — v1.0. Update this file as decisions are made; record formal decisions in TECH-09.*
