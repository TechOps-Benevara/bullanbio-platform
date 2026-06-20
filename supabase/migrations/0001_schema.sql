-- ============================================================================
-- BULLAN BIO DIGITAL PLATFORM — DATABASE SCHEMA
-- Migration 0001 — tables, foreign keys, indexes, triggers
-- ----------------------------------------------------------------------------
-- Source of truth: TECH-05 (Database Schema).
-- Apply with the Supabase CLI (`supabase db push`) or paste into the SQL editor.
-- Create order follows TECH-05 §2 (parents before children).
--
-- DELIBERATE DEVIATIONS FROM TECH-05 (to keep the schema correct):
--   1. Columns that hold a Clerk user ID are `text`, not `uuid` — Clerk IDs
--      look like "user_2ab…", which is not a UUID. Affected:
--        tenants.assigned_am_id, regulations_docs.uploaded_by,
--        kyb_documents.verified_by, tenant_activity_log.user_id (already text).
--   2. `created_at` added to `invoices` and `order_items` to honour the
--      TECH-05 §5 convention that every table has a `created_at`.
--   3. FK constraints use ON DELETE CASCADE from each child → tenants so the
--      registration rollback in api/dealers/register/route.ts works and a
--      tenant can be removed cleanly. Production uses soft deletes
--      (status / active), so cascades rarely fire in practice.
-- ============================================================================

-- gen_random_uuid() is built into PostgreSQL 13+ (Supabase PG15) — no extension needed.

-- Reusable trigger function: keep updated_at current on UPDATE -----------------
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ─── 1. tenants ──────────────────────────────────────────────────────────────
create table tenants (
  id                  uuid primary key default gen_random_uuid(),
  type                text not null check (type in ('company','individual')),
  name                text not null,
  country_code        text not null check (country_code in ('SG','MY','TH','PH','VN','ID')),
  currency            text not null check (currency in ('SGD','MYR','THB','PHP','VND','IDR','USD')),
  status              text not null default 'pending'
                        check (status in ('unverified','pending','active','inactive','archived','rejected')),
  assigned_am_id      text,                              -- Clerk user ID of assigned Account Manager
  email_verified      boolean not null default false,
  agreement_confirmed boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index idx_tenants_status       on tenants(status);
create index idx_tenants_country_code on tenants(country_code);
create trigger trg_tenants_updated before update on tenants
  for each row execute function set_updated_at();

-- ─── 2. dealer_profiles (one row per tenant) ─────────────────────────────────
create table dealer_profiles (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id) on delete cascade,
  company_name      text,
  uen_reg_number    text,
  contact_person    text,
  contact_role      text,
  full_name         text,
  id_number         text,                               -- NRIC/passport — stored ENCRYPTED (AES-256-GCM)
  phone             text not null,
  address           text not null,
  kyb_docs_complete boolean not null default false,
  kyb_reviewed      boolean not null default false,
  notes             text,
  created_at        timestamptz not null default now(),
  constraint uq_dealer_profiles_tenant unique (tenant_id)
);
create index idx_dealer_profiles_tenant on dealer_profiles(tenant_id);

-- ─── 3. tenant_users ─────────────────────────────────────────────────────────
create table tenant_users (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  clerk_user_id text not null,
  role          text not null
                  check (role in ('tenant_owner','tenant_manager','tenant_staff','individual_dealer','sub_dealer')),
  email         text not null,
  full_name     text,
  invited_by    uuid references tenant_users(id) on delete set null,
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  constraint uq_tenant_users_clerk        unique (clerk_user_id),
  constraint uq_tenant_users_tenant_email unique (tenant_id, email)
);
create index idx_tenant_users_tenant on tenant_users(tenant_id);
create index idx_tenant_users_clerk  on tenant_users(clerk_user_id);

-- ─── 4. products (global — not tenant-scoped) ────────────────────────────────
create table products (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  sku                 text not null,
  description         text,
  base_price_usd      numeric(10,2) not null,
  unit                text not null default 'piece' check (unit in ('piece','box','carton','pack')),
  min_order_qty       integer not null default 1 check (min_order_qty >= 1),
  stock_level         integer not null default 0,
  low_stock_threshold integer not null default 10,
  active              boolean not null default true,
  image_url           text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint uq_products_sku unique (sku)
);
create trigger trg_products_updated before update on products
  for each row execute function set_updated_at();

-- ─── 5. orders ───────────────────────────────────────────────────────────────
create table orders (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references tenants(id) on delete cascade,
  placed_by        uuid not null references tenant_users(id) on delete cascade,
  status           text not null default 'draft'
                     check (status in ('draft','submitted','confirmed','invoiced','paid','shipped','delivered','cancelled')),
  internal_status  text check (internal_status in ('draft','submitted')),
  currency         text not null,
  total_amount     numeric(12,2) not null default 0,
  total_amount_usd numeric(12,2) not null default 0,
  notes            text,
  approved_by      uuid references tenant_users(id) on delete set null,
  approved_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_orders_tenant  on orders(tenant_id);
create index idx_orders_status  on orders(status);
create index idx_orders_created on orders(created_at);
create trigger trg_orders_updated before update on orders
  for each row execute function set_updated_at();

-- ─── 6. order_items (unit price locked at order time) ────────────────────────
create table order_items (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references orders(id) on delete cascade,
  product_id     uuid not null references products(id) on delete restrict,
  quantity       integer not null check (quantity > 0),
  unit_price     numeric(10,2) not null,
  unit_price_usd numeric(10,2) not null,
  line_total     numeric(12,2) generated always as (quantity * unit_price) stored,
  created_at     timestamptz not null default now()
);
create index idx_order_items_order   on order_items(order_id);
create index idx_order_items_product on order_items(product_id);

-- ─── 7. invoices (one per order) ─────────────────────────────────────────────
create table invoices (
  id                   uuid primary key default gen_random_uuid(),
  order_id             uuid not null references orders(id) on delete cascade,
  tenant_id            uuid not null references tenants(id) on delete cascade,
  invoice_number       text not null,
  xero_invoice_id      text,
  amount               numeric(12,2) not null,
  amount_usd           numeric(12,2) not null,
  currency             text not null,
  status               text not null default 'draft'
                         check (status in ('draft','sent','paid','overdue','cancelled')),
  airwallex_payment_id text,
  payment_link         text,
  due_date             date,
  issued_at            timestamptz,
  paid_at              timestamptz,
  created_at           timestamptz not null default now(),
  constraint uq_invoices_number unique (invoice_number),
  constraint uq_invoices_order  unique (order_id)
);
create index idx_invoices_tenant on invoices(tenant_id);
create index idx_invoices_status on invoices(status);
create index idx_invoices_order  on invoices(order_id);

-- ─── 8. regulations_docs (global library) ────────────────────────────────────
create table regulations_docs (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  description    text,
  country_code   text not null check (country_code in ('SG','MY','TH','PH','VN','ID','ALL')),
  category       text not null check (category in ('registration','safety','clinical','packaging','import','other')),
  file_url       text not null,
  file_size_kb   integer,
  file_type      text not null check (file_type in ('pdf','jpg','png')),
  version        text,
  uploaded_by    text not null,                          -- Clerk user ID of uploader
  active         boolean not null default true,
  download_count integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index idx_regulations_country  on regulations_docs(country_code);
create index idx_regulations_category on regulations_docs(category);
create trigger trg_regulations_updated before update on regulations_docs
  for each row execute function set_updated_at();

-- ─── 9. kyb_documents (admin-only access — see RLS) ──────────────────────────
create table kyb_documents (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id) on delete cascade,
  doc_type     text not null
                 check (doc_type in ('business_registration','director_id','proof_of_address','distribution_licence','government_id')),
  file_url     text not null,
  file_name    text not null,
  file_size_kb integer,
  file_type    text not null check (file_type in ('pdf','jpg','png')),
  verified     boolean not null default false,
  verified_by  text,                                     -- Clerk user ID of admin who verified
  verified_at  timestamptz,
  uploaded_at  timestamptz not null default now()
);
create index idx_kyb_tenant on kyb_documents(tenant_id);

-- ─── 10. tenant_activity_log (immutable audit trail) ─────────────────────────
create table tenant_activity_log (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  user_id    text not null,                              -- Clerk user ID of the actor
  action     text not null,
  entity     text not null,
  entity_id  uuid,
  metadata   jsonb,
  ip_address text,
  created_at timestamptz not null default now()
);
create index idx_activity_tenant on tenant_activity_log(tenant_id);
create index idx_activity_user   on tenant_activity_log(user_id);

-- End of migration 0001. Row-Level Security policies are in 0002_rls.sql.
