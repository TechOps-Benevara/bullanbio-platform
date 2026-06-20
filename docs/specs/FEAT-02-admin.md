# FEAT-02 — Admin Portal (working mirror)

In-repo summary of **FEAT-02** (authoritative spec is the docx in *Digital Platform / 02 - Feature Specifications*). Source of truth for **Phase 2 (Sprint 2)** and **Phase 3 (Sprint 3)**. Screen designs: `bullanbio_admin_screens.html` and `..._part2.html` (05 - Design and Frontend). The admin portal is Benevara-only; dealers never see it.

---

## 1. Navigation & layout

Three regions: collapsible icon **sidebar** (60px collapsed → 220px on hover; active item = primary blue), contextual **top bar** (breadcrumb, quick actions, notification bell, user avatar), **main content** (24px padding, scrolls independently). **Command palette** on `Cmd/Ctrl-K` searches dealers/orders/products/regulations (max 5 per group, arrow keys + Enter).

### Sidebar items (route → who can see)

| Icon | Label | Route | Visible to |
|---|---|---|---|
| 🏠 | Dashboard | `/admin/dashboard` | All Benevara roles |
| 🤝 | Dealers | `/admin/dealers` | Owner, Super Admin, Account Manager |
| 📦 | Products | `/admin/products` | Owner, Super Admin, Account Manager |
| 📋 | Orders | `/admin/orders` | Owner, Super Admin, Account Manager |
| 🧾 | Invoices | `/admin/invoices` | Owner, Super Admin, Finance Manager |
| 📚 | Regulations | `/admin/regulations` | All Benevara roles |
| 👥 | Team | `/admin/team` | Owner, Super Admin only |
| ⚙️ | Settings | `/admin/settings` | Owner only |

---

## 2. Role-based dashboards

- **Owner / Super Admin:** Pending Actions + Intelligence + Finance Snapshot + Team Overview (full view).
- **Account Manager:** My Dealers, My Order Queue, Pending Approvals, Intelligence (read-only). No finance/team.
- **Finance Manager:** Revenue Overview, Invoice Queue, Payment Tracking, Integration Status (Airwallex/Xero), Intelligence (read-only). No dealer/product/team.

**Intelligence widgets:** order volume by country (bar, 7/30/90d), top 5 products by units, dealer activity (active vs quiet 30d+), stock velocity (weeks-to-out), basic demand forecast. **Forecast shows "Not enough data yet — forecast will appear after 3+ orders per product" until enough data exists.**

---

## 3. Dealer management

- **List** (`/admin/dealers`): search (name/contact/email), filters (status / country / type / assigned AM), columns (name, type, country flag, status badge, AM, last order, KYB status, actions), 50/page, row click → slide-in detail panel.
- **Pending queue** (`?status=pending`): per-dealer card with document checklist, agreement checkbox, **Approve disabled until all required docs uploaded AND agreement ticked**, Reject (reason required), Send reminder, days-waiting badge (amber >3d, red >7d).
- **Detail panel** (slide-in): tabs Profile / Documents (view + mark verified) / Orders / Activity; AM dropdown (saves immediately); status controls (Activate/Deactivate/Archive — deactivate needs reason); Send welcome email (when approved but no password yet).
- **Add Dealer modal (Path C)** and **Send Invite modal (Path B, 7-day link)** — see FEAT-01.
- **Team management** (`/admin/dealers/[id]/team`): staff list with role badges; change role (cannot demote the only Tenant Owner); deactivate; sub-dealer network view for individual dealers.

---

## 4. Product management (`/admin/products`)

List (search by name/SKU, filter by status/stock), add/edit modal (name, SKU **unique**, description, base price USD, unit, min order qty, stock level, low-stock threshold, image, active toggle), hide = `active=false`. **Stock:** reserved on order confirm, returned on cancel-after-confirm; manual adjust needs a reason. MVP stock is basic (no warehouse/batch/expiry).

---

## 5. Order management (`/admin/orders`) — Sprint 3

- **List:** only `submitted`+ (never drafts); search/filter/sort; status badges; counts by status.
- **Detail panel:** order summary, read-only line items, status update (forward-only, each change needs a note + emails dealer), internal notes, invoice section (Generate/View), logistics section (courier + tracking, manual for MVP), activity log.
- **Status update rules:** see `docs/specs/order-status-flow.md`.

---

## 6. Regulations library — admin (`/admin/regulations`)

Upload modal (title, description, country incl. `ALL`, category, version, file PDF/JPG/PNG ≤10MB → Supabase Storage). List with search/filter (country / category / status). Actions: edit metadata (no re-upload), replace file (new version), hide (`active=false`), delete. **Bucket access = Decision Gate C (F3)** — see `docs/DECISIONS.md`.

---

## 7. Team management (`/admin/team`) — Owner & Super Admin only

Team list (name, email, role badge, status, dealers assigned, last active). Add team member (Clerk invite with role pre-assigned). Change role (except Owner), deactivate. **Owner row is locked** (no actions). Dealer assignment screen (`/admin/team/assignments`): AMs with their dealers, unassigned dealers flagged amber, drag-drop or dropdown to reassign (logs activity, no dealer notification).

---

## 8. Permissions

See `docs/RBAC-matrix.md` (Admin portal matrix). **Enforce every permission server-side in the API routes — UI hiding is not security.**

---

## 9. Definitions of Done

- **Sprint 2:** layout, role dashboards, dealer list/detail/queue/approve/reject, Add/Invite, product CRUD + hide, regulations upload/search — all pass live; tests green; reviewed.
- **Sprint 3:** order list/detail/status flow, status emails, stock reserve/return, notes, logistics fields, regulations tag/version/delete — all pass live; admin portal fully operational; tests green; reviewed.

(Full per-item checklists are in the FEAT-02 docx. Build steps in `docs/DEVELOPMENT_ROADMAP.md §7–8`.)
