# docs/ — project documentation index

Everything Claude Code (and the team) needs to build the platform, readable natively in the repo. The product/technical specs originate as `.docx` in the SharePoint *Digital Platform* folder; the files here are working mirrors of the parts needed for the build. **If a mirror and the docx disagree, the docx wins — flag it.**

## Start here
- **[DEVELOPMENT_ROADMAP.md](./DEVELOPMENT_ROADMAP.md)** — the phased build plan (Phase 0 → Sprints 1–5), Decision Gates, and findings tracker. Read this first.
- **[../CLAUDE.md](../CLAUDE.md)** — operating manual & conventions (auto-loaded by Claude Code).
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** — branch strategy (`develop` → PR → `main` after E2E) and commit format.

## Reference
- **[RBAC-matrix.md](./RBAC-matrix.md)** — 10 roles, permission matrices, token claims.
- **[DECISIONS.md](./DECISIONS.md)** — ADR log; the three open Decision Gates (A/B/C) live here.
- **[specs/FEAT-01-auth.md](./specs/FEAT-01-auth.md)** — login, auth, registration (Sprint 1).
- **[specs/FEAT-02-admin.md](./specs/FEAT-02-admin.md)** — admin portal (Sprints 2–3).
- **[specs/order-status-flow.md](./specs/order-status-flow.md)** — order lifecycle & transition rules.

## Database
- **[../supabase/migrations/0001_schema.sql](../supabase/migrations/0001_schema.sql)** — 10 tables, FKs (with cascade), indexes, triggers.
- **[../supabase/migrations/0002_rls.sql](../supabase/migrations/0002_rls.sql)** — RLS policies (⚠ apply only after Gate A/B).

## Not yet mirrored (read from the docx if needed)
TECH-01 (project overview), TECH-02 (sprint plan), TECH-03 (architecture), TECH-04 (tech stack), MAN-01 (user manual), and the full per-item Sprint checklists in FEAT-01/02.
