# Decision log (ADRs)

In-repo record of architectural decisions so Claude Code can read and append to them without leaving the codebase. The **canonical** log is TECH-09 (Decision & Build Log) in SharePoint — mirror every decision here too. Each entry is short: context, options, decision, consequences.

The three **open Decision Gates** below block the code that depends on them (see `docs/DEVELOPMENT_ROADMAP.md §3`). Resolve A and B before building any tenant-data feature; resolve C before the regulations feature.

---

## ADR-0001 — Tenant isolation model (Gate A · F1)
**Status:** 🔴 OPEN — blocks all RLS-dependent features (Sprints 2–5)

**Context.** Every server route currently uses `supabaseAdmin` (service-role key), which **bypasses RLS**. TECH-03 claims RLS protects tenant data "even with application bugs" — that only holds if reads go through a user-context client whose Clerk JWT carries the tenant claims.

**Options.**
1. **RLS-enforced** — read/write via the anon client carrying a Clerk-issued Supabase JWT; RLS is the real backstop. Requires the Clerk↔Supabase token integration (ADR-0002).
2. **Application-enforced** — keep the service-role client; RLS is a secondary net; **every** tenant query must include an explicit `.eq('tenant_id', …)` filter, covered by tests.

**Decision.** _TBD._
**Consequences.** _TBD._

---

## ADR-0002 — Clerk ↔ Supabase token & claim sync (Gate B · F2)
**Status:** 🔴 OPEN — blocks anything reading role/tenant claims

**Context.** Middleware authz and the RLS policies (`0002_rls.sql`) need `role`, `tenant_id`, `tenant_role`, `tenant_user_id`, `sub` in the session token. The Sprint 1 Clerk webhook only handles email-verified and user-deleted — there is no sync path for role/tenant changes.

**Options.** Supabase native third-party-auth with Clerk (recommended; confirm against current docs) + a Clerk token template carrying the claims + webhook/handlers that set `publicMetadata` on approval, role change, and AM assignment, plus a reconciliation check vs `tenant_users`.

**Decision.** _TBD._
**Consequences.** _TBD._

---

## ADR-0003 — Regulations bucket access (Gate C · F3)
**Status:** 🔴 OPEN — blocks the regulations upload/download feature (Sprint 2)

**Context.** Spec says regulations are for authenticated users; Package 1 setup makes the `regulations` bucket public-read (URL-guessable, no auth).

**Options.**
1. Private bucket + signed URLs (use the existing `getSignedUrl` helper).
2. Genuinely public — if so, correct the spec so the two agree.

**Decision.** _TBD._
**Consequences.** _TBD._

---

## Template for new ADRs

```
## ADR-000N — <title>
**Status:** Proposed | Accepted | Superseded — <date>
**Context.** <why a decision is needed>
**Options.** <the choices considered>
**Decision.** <what was chosen, by whom>
**Consequences.** <trade-offs, follow-ups, what to revisit>
```
