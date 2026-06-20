-- ============================================================================
-- BULLAN BIO DIGITAL PLATFORM — ROW-LEVEL SECURITY
-- Migration 0002 — RLS policies (transcribed from TECH-05)
-- ----------------------------------------------------------------------------
-- ⚠  DO NOT APPLY until Decision Gates A & B (TECH-REVIEW-01 F1/F2) are resolved.
--
-- These policies assume the session JWT — issued via the Clerk ↔ Supabase
-- integration — carries these claims:
--     role            Benevara role: owner | super_admin | account_manager | finance_manager
--     tenant_id       the caller's tenant UUID (dealers only)
--     tenant_role     tenant_owner | tenant_manager | tenant_staff | individual_dealer | sub_dealer
--     tenant_user_id  the caller's tenant_users.id (UUID) — needed for "own order" checks
--     sub             the caller's Clerk user ID (standard JWT subject)
--
-- Until that integration is wired, these policies will deny everything for a
-- normal session. The server's `supabaseAdmin` client (service-role key)
-- BYPASSES every policy below — that is how registration, webhooks, and
-- trusted admin operations write data.
--
-- Casting note: (auth.jwt() ->> 'tenant_id')::uuid yields NULL when the claim
-- is absent, so the comparison simply fails to match (safe default-deny).
-- ============================================================================

-- Enable RLS on every table ---------------------------------------------------
alter table tenants             enable row level security;
alter table dealer_profiles     enable row level security;
alter table tenant_users        enable row level security;
alter table products            enable row level security;
alter table orders              enable row level security;
alter table order_items         enable row level security;
alter table invoices            enable row level security;
alter table regulations_docs    enable row level security;
alter table kyb_documents       enable row level security;
alter table tenant_activity_log enable row level security;

-- ─── tenants ─────────────────────────────────────────────────────────────────
create policy benevara_read_tenants on tenants for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager','finance_manager'));
create policy tenant_read_own on tenants for select
  using (id = (auth.jwt() ->> 'tenant_id')::uuid);
create policy benevara_insert_tenants on tenants for insert
  with check (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_update_tenants on tenants for update
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy tenant_owner_update_own on tenants for update
  using (id = (auth.jwt() ->> 'tenant_id')::uuid and auth.jwt() ->> 'tenant_role' = 'tenant_owner');

-- ─── dealer_profiles (Benevara admin; tenant reads own) ──────────────────────
create policy benevara_read_profiles on dealer_profiles for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager','finance_manager'));
create policy tenant_read_own_profile on dealer_profiles for select
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);
create policy benevara_write_profiles_ins on dealer_profiles for insert
  with check (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_write_profiles_upd on dealer_profiles for update
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy tenant_owner_update_own_profile on dealer_profiles for update
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid and auth.jwt() ->> 'tenant_role' = 'tenant_owner');

-- ─── tenant_users (Benevara admin; tenant reads own team) ────────────────────
create policy benevara_read_tenant_users on tenant_users for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager','finance_manager'));
create policy tenant_read_own_team on tenant_users for select
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);
create policy tenant_owner_manage_team_ins on tenant_users for insert
  with check (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
              and auth.jwt() ->> 'tenant_role' in ('tenant_owner','individual_dealer'));
create policy tenant_owner_manage_team_upd on tenant_users for update
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
         and auth.jwt() ->> 'tenant_role' in ('tenant_owner','individual_dealer'));
create policy benevara_manage_tenant_users on tenant_users for insert
  with check (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));

-- ─── products (everyone reads active; Benevara manages) ──────────────────────
create policy all_read_active_products on products for select
  using (active = true);
create policy benevara_read_all_products on products for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager','finance_manager'));
create policy benevara_products_insert on products for insert
  with check (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_products_update on products for update
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_products_delete on products for delete
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));

-- ─── orders (Benevara never sees drafts; tenants see own per role) ───────────
create policy benevara_read_orders on orders for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager','finance_manager')
         and status <> 'draft');
create policy tenant_lead_read_orders on orders for select
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
         and auth.jwt() ->> 'tenant_role' in ('tenant_owner','tenant_manager','individual_dealer'));
create policy tenant_member_read_own_orders on orders for select
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
         and auth.jwt() ->> 'tenant_role' in ('tenant_staff','sub_dealer')
         and placed_by = (auth.jwt() ->> 'tenant_user_id')::uuid);
create policy tenant_insert_orders on orders for insert
  with check (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
              and auth.jwt() ->> 'tenant_role' in
                  ('tenant_owner','tenant_manager','tenant_staff','individual_dealer','sub_dealer'));
create policy tenant_lead_update_orders on orders for update
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
         and auth.jwt() ->> 'tenant_role' in ('tenant_owner','tenant_manager'));
create policy benevara_update_orders on orders for update
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager')
         and status <> 'draft');

-- ─── order_items (inherit visibility from the parent order) ──────────────────
-- The sub-selects below are themselves filtered by the orders policies above,
-- so a user only sees / edits items of orders they can already see.
create policy read_order_items on order_items for select
  using (exists (select 1 from orders o where o.id = order_items.order_id));
create policy insert_order_items on order_items for insert
  with check (exists (select 1 from orders o
                      where o.id = order_items.order_id and o.status in ('draft','submitted')));
create policy update_order_items on order_items for update
  using (exists (select 1 from orders o
                 where o.id = order_items.order_id and o.status in ('draft','submitted')));
create policy delete_order_items on order_items for delete
  using (exists (select 1 from orders o
                 where o.id = order_items.order_id and o.status in ('draft','submitted')));

-- ─── invoices (finance roles full; tenant leads read own; staff/sub none) ────
create policy benevara_finance_read_invoices on invoices for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','finance_manager'));
create policy benevara_finance_insert_invoices on invoices for insert
  with check (auth.jwt() ->> 'role' in ('owner','super_admin','finance_manager'));
create policy benevara_finance_update_invoices on invoices for update
  using (auth.jwt() ->> 'role' in ('owner','super_admin','finance_manager'));
create policy tenant_read_own_invoices on invoices for select
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
         and auth.jwt() ->> 'tenant_role' in ('tenant_owner','tenant_manager','individual_dealer'));

-- ─── regulations_docs (everyone reads active; Benevara admin manages) ────────
create policy all_read_active_regulations on regulations_docs for select
  using (active = true);
create policy benevara_read_all_regulations on regulations_docs for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager','finance_manager'));
create policy benevara_regulations_insert on regulations_docs for insert
  with check (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_regulations_update on regulations_docs for update
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_regulations_delete on regulations_docs for delete
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));

-- ─── kyb_documents (Benevara admin ONLY — dealers have no access) ────────────
-- Dealers upload via the server (supabaseAdmin) during registration; they can
-- never read or modify KYB docs through a normal session.
create policy benevara_read_kyb on kyb_documents for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_insert_kyb on kyb_documents for insert
  with check (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));
create policy benevara_update_kyb on kyb_documents for update
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager'));

-- ─── tenant_activity_log (immutable: select + insert only) ───────────────────
create policy benevara_read_activity on tenant_activity_log for select
  using (auth.jwt() ->> 'role' in ('owner','super_admin','account_manager','finance_manager'));
create policy tenant_lead_read_activity on tenant_activity_log for select
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
         and auth.jwt() ->> 'tenant_role' in ('tenant_owner','tenant_manager','individual_dealer'));
create policy tenant_member_read_own_activity on tenant_activity_log for select
  using (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
         and auth.jwt() ->> 'tenant_role' in ('tenant_staff','sub_dealer')
         and user_id = (auth.jwt() ->> 'sub'));
create policy self_insert_activity on tenant_activity_log for insert
  with check (user_id = (auth.jwt() ->> 'sub'));
-- No UPDATE or DELETE policies: the activity log is immutable.

-- End of migration 0002.
