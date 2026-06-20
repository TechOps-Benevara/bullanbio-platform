# RBAC — Roles & Permission Matrix

In-repo mirror of FEAT-01 §8 and FEAT-02 §8 so Claude Code can read it natively.
**Authoritative source:** FEAT-01 (Login, Authentication & RBAC) and FEAT-02 (Admin Portal) in the SharePoint *Digital Platform* folder. If this file and those disagree, the docx wins — flag it.

Enforcement is layered: **Clerk** assigns roles and issues the session token → **Clerk middleware** protects routes server-side → **Supabase RLS** isolates data at the database level (see `supabase/migrations/0002_rls.sql`).

---

## The 10 roles

| Level | Role (`publicMetadata.role`) | Side | Who | In one line |
|---|---|---|---|---|
| 0 | `owner` | Benevara | Benny (one account) | Everything. Cannot be deleted/demoted by anyone. |
| 1 | `super_admin` | Benevara | Jessica | Full platform access; manages all roles except Owner. |
| 2 | `account_manager` | Benevara | Sales/ops | Full lifecycle for **assigned** dealers; orders, logistics, dealer accounts. |
| 3 | `finance_manager` | Benevara | Irene | Invoices & payments, Xero/Airwallex. No dealer/product management. |
| 4 | `tenant_owner` | Company tenant | Company registrant | Full control within own tenant; manage staff; approve orders. |
| 5 | `tenant_manager` | Company tenant | Senior staff | Approve staff orders; see all company orders; download invoices. |
| 6 | `tenant_staff` | Company tenant | Operational staff | Place **draft** orders (need approval); see only own orders. |
| 7 | `individual_dealer` | Individual network | Independent rep | Network owner; manage sub-dealers; order independently; own invoices. |
| 8 | `sub_dealer` | Individual network | Reports to dealer | Order independently (straight to Benevara); see only own orders. |
| 9 | `hospital_user` | (Future — Phase 4) | Endoscopy centres | Log usage, access regulations. No ordering. |

**Owner protection:** the Level 0 account can never be deleted, demoted, or modified by any other role — including Super Admin.

---

## Permission matrix — platform-wide (FEAT-01 §8.5)

| Permission | Owner | S.Admin | Acct Mgr | Finance | T.Owner | T.Mgr | T.Staff |
|---|---|---|---|---|---|---|---|
| Manage platform settings | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Manage all dealer accounts | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage own tenant staff | — | — | — | — | ✅ | ❌ | ❌ |
| Create orders (on behalf) | ✅ | ✅ | ✅ | ❌ | — | — | — |
| Place orders | — | — | — | — | ✅ | ✅ | Draft only |
| Approve internal orders | — | — | — | — | ✅ | ✅ | ❌ |
| See all orders (platform) | ✅ | ✅ | Assigned | ❌ | ❌ | ❌ | ❌ |
| See all company orders | — | — | — | — | ✅ | ✅ | Own only |
| Generate invoices | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Record payments | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xero integration | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Airwallex integration | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Download invoices | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Update logistics status | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage products | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Regulations library (read) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manage regulations library | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

> Note (reconciliation): per FEAT, `individual_dealer` downloads their own invoices and sees their network's activity; `sub_dealer` places orders straight to Benevara and sees only their own. These are reflected in the RLS policies.

---

## Permission matrix — Admin portal features (FEAT-02 §8)

| Feature | Owner | S.Admin | Acct Mgr | Finance Mgr |
|---|---|---|---|---|
| View dashboard | ✅ | ✅ | ✅ | ✅ |
| View intelligence section | ✅ | ✅ | ✅ | ✅ |
| View finance section | ✅ | ✅ | ❌ | ✅ |
| View team section | ✅ | ✅ | ❌ | ❌ |
| View settings | ✅ | ❌ | ❌ | ❌ |
| View all dealers | ✅ | ✅ | Assigned only | ❌ |
| Approve / reject dealer | ✅ | ✅ | ✅ | ❌ |
| Add dealer (Path C) / Send invite (Path B) | ✅ | ✅ | ✅ | ❌ |
| Edit dealer profile | ✅ | ✅ | ✅ | ❌ |
| Deactivate dealer | ✅ | ✅ | ❌ | ❌ |
| View KYB documents | ✅ | ✅ | ✅ | ❌ |
| Assign Account Manager | ✅ | ✅ | ❌ | ❌ |
| Manage products | ✅ | ✅ | ✅ | ❌ |
| View all orders | ✅ | ✅ | Assigned dealers | ✅ |
| Confirm order / update status | ✅ | ✅ | ✅ | ❌ |
| Generate / send invoice, record payment | ✅ | ✅ | ❌ | ✅ |
| View invoices | ✅ | ✅ | ❌ | ✅ |
| Upload / manage regulations | ✅ | ✅ | ✅ | ❌ |
| Add team members / change roles / deactivate | ✅ | ✅ | ❌ | ❌ |

**Enforcement rule:** the UI hides what a role cannot do, but **every API route must re-check the permission server-side**. UI hiding is not security.

---

## Token claims the policies rely on (Gate B)

The Clerk session token must carry these claims for middleware authz and Supabase RLS to work (see `supabase/migrations/0002_rls.sql` header):

| Claim | Meaning |
|---|---|
| `role` | Benevara role (Levels 0–3) — empty for dealers |
| `tenant_id` | The caller's tenant UUID (dealers) |
| `tenant_role` | Dealer-side role (Levels 4–8) |
| `tenant_user_id` | The caller's `tenant_users.id` (UUID) — for "own order" checks |
| `sub` | The caller's Clerk user ID (standard JWT subject) |

Wiring these claims is **Decision Gate B (F2)** — see `docs/DECISIONS.md`.
