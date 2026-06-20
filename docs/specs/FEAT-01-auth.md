# FEAT-01 — Login, Authentication & Registration (working mirror)

In-repo summary of **FEAT-01** (the authoritative spec is the docx in *Digital Platform / 02 - Feature Specifications*). This is the source of truth for **Phase 1 / Sprint 1**. The login page design is `bullanbio_login.html` (05 - Design and Frontend) — convert it faithfully; **do not change the design without Benny's sign-off.**

---

## 1. Login page

Single entry at `bullanbio.com`. Two-panel layout.

- **Left panel:** Bullan Bio × Benevara branding, four portal cards (Admin, Dealer, Logistics, Hospital), Bullan Cleaning Ball product card, IP location chip (after detection), Benevara footer (UEN 202426130K).
- **Right panel:** Sign-in heading, personalised subtitle, Google SSO, Microsoft SSO, divider, email + password (show/hide), Forgot password link, Sign in, Register here link, domain badge, footer.

**Sign-in methods (all user types):** Google SSO, Microsoft SSO, email + password — all via Clerk.

**IP geolocation:** runs silently on load (ip-api.com dev / ipinfo.io prod). If detected → location chip + "Welcome from [Country] — sign in to continue", and pre-sets currency context. **Must never block or delay login** — silent fail, default USD.

### Login page states

| State | Trigger | What the user sees |
|---|---|---|
| Default | Page load | Branding + sign-in form; IP detection running silently |
| Location detected | IP API returns | Location chip + personalised subtitle |
| Loading | Sign in clicked | Button spinner; fields disabled; no double-submit |
| Wrong password | Bad credentials | "Incorrect email or password." Forgot-password link highlighted |
| Unverified | Login before email verified | "Please verify your email." Resend link shown |
| Pending | Verified, awaiting approval | "Your account is under review…" |
| Inactive | Deactivated by admin | "Your account has been deactivated. Contact Benevara…" |
| Success — Benevara | Role 0–3 | Redirect `/admin/dashboard` |
| Success — Dealer (active) | Dealer role, active | Redirect `/dealer/dashboard` |

---

## 2. Three dealer access paths

- **Path A — Self-register + admin approval** (default). Full form + KYB docs + agreement checkbox → email verify (48h) → status `unverified → pending` → admin reviews & approves → welcome email → set password → login.
- **Path B — Invite link.** Admin sends a Clerk invite (expires **7 days**). Simplified form, KYB upload, **auto-activated** (no approval queue). Email implicitly verified.
- **Path C — Admin creates account.** Admin fills everything + uploads KYB + confirms agreement, sets status Active/Pending, sends welcome email (clicking the link verifies email).

**Rejection (Path A):** admin must enter a reason → dealer emailed → status `rejected` → dealer can correct docs and resubmit (tagged "Resubmission"). Account is never deleted.

---

## 3. Registration form fields

**Company dealer:** dealer type (radio), legal company name*, UEN/registration number*, contact person*, contact role, business email*, phone*, country* (pre-filled from IP), business address*, password* (Path A/C only, min 8 / 1 upper / 1 number), agreement checkbox*.

**Individual dealer:** dealer type (radio), full legal name*, NRIC/passport number* (stored **encrypted**, shown last-4 only), email*, phone*, country*, personal address*, password* (Path A/C only), agreement checkbox*.

(\* = required. Password field is absent in Path B — Clerk handles it via the invite.)

---

## 4. KYB documents

**Company — required:** business registration certificate (ACRA/SSM/DBD/SEC/etc.), director/authorised-signatory ID, proof of business address (≤3 months). **Optional:** medical-device distribution licence (flag in queue if provided).

**Individual — required:** government-issued ID (NRIC/passport), proof of address (≤3 months).

**File rules:** PDF/JPG/PNG, max **10 MB**/file, max 5 files/type. Stored in the private `kyb-documents` bucket (Benevara admin only via RLS). Dealers can submit without all docs, but **cannot be approved** until all required docs are uploaded and verified. Documents are never deleted (archived with the dealer).

### Document reminder schedule

| Day | Action |
|---|---|
| 0 | Registration submitted; verification email sent |
| 1 | Email verified → status `pending`; appears in admin queue |
| 3 | Reminder email if docs incomplete |
| 6 | Final reminder ("archived in 24h") |
| 7 | Auto-archive if docs still missing (reactivatable) |

> These reminders/auto-archive need a scheduled job (Vercel Cron / `pg_cron`) — see roadmap Phase 1 step 10 (F5).

---

## 5. Admin approval queue — 4-check gate

A dealer can be **Approved** only when all four are complete (Approve button disabled otherwise):

1. **Email verified** — automatic (Clerk); admin cannot override.
2. **KYB documents uploaded** — automatic (all required files present).
3. **KYB documents reviewed** — manual (admin opens each).
4. **Agreement signed** — manual checkbox ("signed & confirmed externally").

---

## 6. Forgot password

Click → email input → always show "If an account with that email exists a reset link has been sent." (no enumeration) → Clerk reset link (expires **1 hour**) → set new password (min 8 / 1 upper / 1 number) → sign in.
**SSO users:** if a Google/Microsoft user clicks Forgot password, tell them to reset via their Google/Microsoft account — they have no Bullan Bio password.

---

## 7. Email notifications (all via Clerk, Bullan Bio branded, Benevara footer + UEN)

Combined verify+pending (Path A, 48h) · document reminder day 3 · final reminder day 6 · account archived day 7 · invite link (Path B, 7d) · welcome email (after approval / Path C, password link 48h) · password reset (1h) · new-registration-pending (to all Benevara admins) · account rejected (with reason) · account deactivated.

---

## 8. Security requirements (non-negotiable for Sprint 1)

HTTPS only · password min 8 / 1 upper / 1 number (Clerk) · Clerk rate limiting on failed logins (keep on) · passwords only in Clerk · session expiry 7 days · NRIC/passport encrypted, last-4 display · KYB bucket admin-only via RLS · forgot-password no email enumeration · secrets only in env vars · admin routes protected server-side · Owner account immutable · tenant data isolation via RLS.

---

## 9. Sprint 1 Definition of Done

All 37 items in the FEAT-01 Sprint 1 checklist pass live on bullanbio.com, Jest + Playwright green, reviewed by Benny + Jessica. See the docx for the full checklist; see `docs/DEVELOPMENT_ROADMAP.md §6` for the build steps and the code-review integration notes.
