# Order status flow

In-repo mirror of TECH-05 §4 and FEAT-02 §5.3. The `orders.status` and `orders.internal_status` columns are defined in `supabase/migrations/0001_schema.sql`.

## Status sequence

```
draft → submitted → confirmed → invoiced → paid → shipped → delivered
                                                              ↘ (any) → cancelled
```

| Status | Set by | Meaning / trigger |
|---|---|---|
| `draft` | Tenant Staff (auto on create) | Internal to the company tenant. **Benevara cannot see drafts.** Awaiting internal approval. |
| `submitted` | Tenant Manager / Owner | Internal approval given → now visible to Benevara. |
| `confirmed` | Account Manager (or above) | Benevara confirms. **Stock reserved.** Email to dealer. |
| `invoiced` | Finance Manager (or above) | Invoice generated → pushed to Xero, Airwallex payment link created, emailed to dealer. |
| `paid` | Finance Manager (auto via Airwallex webhook, or manual) | Payment confirmed → Xero updated, activity logged. |
| `shipped` | Account Manager (or above) | Courier + tracking entered (manual for MVP). Email to dealer. |
| `delivered` | Account Manager (or above) | Order closed; activity logged; dealer notified. |
| `cancelled` | Account Manager or Tenant Owner | Allowed at any stage. **Reason required.** Stock returned if was confirmed+. Xero updated if invoiced+. |

## Rules

- **Forward-only** progression in the admin UI (cannot move a status backwards). Each change **requires a note** and **emails the dealer**.
- **Company tenants** use the internal approval stage: staff create `draft` → manager/owner promote to `submitted`. `internal_status` carries `draft`/`submitted`.
- **Individual dealers and sub-dealers skip `draft`** — their orders are created as `submitted` (`internal_status = NULL`); Benevara sees them immediately.
- Benevara queries only `status <> 'draft'` (enforced in RLS — `benevara_read_orders`).
- Order line items (`order_items`) can be inserted/edited only while the order is `draft` or `submitted` (enforced in RLS); unit price is locked at order time.
