# sweep.je — Product & Technical Specification

> A web app for creating and running **sweepstakes** (the office/social kind):
> an organizer creates a pool of entries (e.g. the 48 World Cup teams), shares a
> link, people register with just their name, and a provably-recorded random draw
> assigns each participant one or more entries.

**Status:** Draft v1 — target: production-ready first release.
**Last updated:** 2026-05-31

---

## 1. Vision & Scope

### 1.1 One-line pitch
sweep.je lets anyone spin up a fair, shareable sweepstake for their company,
family, or friends in under a minute — no spreadsheets, no "names in a hat."

### 1.2 What it is
A **sweepstake** here is the traditional draw where a fixed set of **entries**
(typically sports teams, but could be anything) are randomly distributed among
**participants**. Example: an office World Cup sweepstake where each of 16 people
is randomly assigned 3 of the 48 teams.

This is **not** a prize-lottery / giveaway product. There is **no purchase, no
payment, and no monetary prize handled by the platform.** Entry is always free.
Any prize/stake arrangement is private to the organizer and out of scope for the
software. This keeps us clear of gambling-licensing concerns (see §10).

### 1.3 Goals (first release)
- Authenticated **organizers** can create a sweepstake from a **template** (a
  pre-built competition like *World Cup 2026* with teams pre-loaded) or by
  **manually** entering their own entries.
- The platform issues a **shareable link**. Anyone with the link can open it,
  **see who has already registered** and the **draw date**, and **register with
  just their name** (no account, no login).
- A **provably-recorded random draw** assigns entries to participants using
  **auto-balanced** allocation, with a stored seed + audit log anyone can use to
  re-verify the result.
- The draw can be **scheduled** to run automatically at a set date/time **and**
  triggered **manually/early** by the organizer.
- An **admin dashboard** for organizers to manage their sweepstakes, registrants,
  and draws; plus a platform **super-admin** area to manage competition templates.

### 1.4 Non-goals (first release)
- Payments, paid entries, subscriptions, or prize disbursement.
- Native mobile apps (the API and React app are built mobile-ready; native comes
  later — see §12).
- Real-time scoring / live competition results / leaderboards tied to actual
  match outcomes. (Candidate for a later phase.)
- Social network features (following, feeds, messaging).

---

## 2. Personas & Roles

| Role | Auth | Description |
|------|------|-------------|
| **Organizer** | Account (email + password / OAuth) | Creates and manages sweepstakes, runs draws, manages registrants. Owns the data for their sweepstakes. |
| **Participant** | None (name only) | Opens a share link and registers with a display name. Identified by a per-sweepstake token stored in their browser. No password, no email required. |
| **Platform Admin** | Account + elevated role | Manages competition **templates**, moderates content, sees platform-wide metrics. Internal/staff. |

> **Participant identity:** Because participants don't log in, after registering
> they receive a **claim token** (random, stored in localStorage + returned in the
> URL once). This lets them return to "their" registration and see their assigned
> entries after the draw, without an account. Losing the token = losing the ability
> to edit their own registration, but the organizer can always see/manage it.

---

## 3. Core Concepts & Glossary

- **Sweepstake** — A single draw event owned by one organizer. Has a name, draw
  date/time, status, a set of entries, and a set of participants.
- **Entry** — One item to be drawn (e.g. "Brazil", "England"). Belongs to a
  sweepstake. May originate from a template or be manually added.
- **Participant** — A person who registered to a sweepstake (name + claim token).
- **Allocation** — The result linking a participant to one or more entries,
  produced by the draw.
- **Template (Competition)** — A reusable, admin-curated set of entries (e.g.
  *World Cup 2026* → 48 national teams). Selecting a template seeds a new
  sweepstake's entries.
- **Draw** — The act of randomly assigning entries to participants. Records a
  seed, algorithm version, timestamp, and the resulting allocations (immutable).
- **Share link** — The public URL (with an unguessable slug) that participants use
  to view and register.

---

## 4. Key User Flows

### 4.1 Organizer creates a sweepstake
1. Sign up / log in.
2. "New sweepstake" → enter name, optional description, **draw date/time**, and
   timezone.
3. Choose entries source:
   - **From template:** pick a competition (e.g. *World Cup 2026*). Entries
     auto-populate (editable — can remove/add/rename).
   - **Manual:** add entries one-by-one or paste a list (one per line).
4. Configure options: allocation rule (default **auto-balance**), whether
   registration is **open/closed**, optional **max participants**, whether
   participant list is **public** on the share page (default: yes).
5. Save → platform generates the **share link** and a **manage** view.

### 4.2 Participant registers
1. Opens share link.
2. Sees: sweepstake name, organizer/host name, **draw date (with countdown)**,
   **list of already-registered participants**, number of entries, and status.
3. If registration is open and not full: enters their **name** → submits.
4. Receives confirmation; their name now appears in the list. A **claim token**
   is saved so they can return to see their result.
5. If the draw has already happened: the page shows results — each participant and
   their assigned entries; the viewer's own allocation is highlighted if they hold
   a claim token.

### 4.3 Running the draw
- **Scheduled (auto):** at the set date/time, a background job locks registration
  and runs the draw automatically.
- **Manual/early:** the organizer clicks "Run draw now." Confirmation warns that
  this locks registration and is final.
- On draw: registration locks, allocations are computed (see §6), results become
  visible on the share page, and (later phase) notifications fire.
- A draw is **idempotent and immutable** once run. Re-running requires an explicit
  organizer "reset draw" action (logged), which clears allocations and reopens.

### 4.4 Verifying fairness
- Each completed draw exposes a **verification panel**: the **seed**, **algorithm
  version**, **ordered participant list**, **ordered entry list**, and **timestamp**.
- We publish the deterministic algorithm (§6.2) so anyone can re-run it with the
  shown seed and confirm they get the identical allocation. A copy-paste
  verification snippet / page is provided.

---

## 5. Templates (Competitions)

Templates are admin-curated and versioned so a future edit doesn't mutate past
sweepstakes.

- **Shipped at launch:**
  - **FIFA World Cup 2026** — 48 teams. *(Note: the 2026 tournament expanded to 48
    teams; the template must reflect 48, not 32.)* **This is the only template at
    launch;** additional competitions (e.g. Euro, Premier League) come later.
- **Template shape:** `name`, `slug`, `category` (e.g. football), `season/year`,
  `status` (draft/published/archived), ordered list of entries (each with display
  name + optional metadata: country code/flag emoji, group, seed).
- **Usage:** selecting a template **copies** its entries into the sweepstake
  (decoupled — later template edits don't affect existing sweepstakes).
- **Admin CRUD** for templates lives in the Platform Admin area.

---

## 6. The Draw — Allocation & Fairness

### 6.1 Allocation rule: Auto-balance
Distribute all entries across participants as evenly as possible.

- Let `E` = number of entries, `P` = number of participants.
- Each participant receives **floor(E/P)** entries; the **E mod P** leftover
  entries are assigned to a randomly chosen subset of participants (one extra
  each). With 16 people and 48 entries → everyone gets exactly 3. With 17 people
  and 48 entries → 14 get 3 and 3 get 2 (randomly chosen), etc.
- If `P > E`: some participants get **zero** entries (chosen randomly). The UI must
  surface this clearly before the draw ("More participants than entries — some
  won't be assigned").
- Edge cases: `P = 0` → draw disallowed. `E = 0` → draw disallowed.

> **Future:** "one entry per person" (strict 1:1) and "organizer picks per draw"
> are noted as later allocation modes; the schema (`allocation_rule` on the
> sweepstake) is designed to accommodate them now.

### 6.2 Fairness model: Auditable seeded shuffle
Chosen approach for v1 — **auditable log** (lightweight, no external dependency):

1. When a draw runs, the server generates a cryptographically secure random
   **seed** (e.g. 256-bit, hex-encoded).
2. Build the canonical inputs: participants ordered by `created_at, id`; entries
   ordered by `position, id`.
3. Run a **deterministic, seeded Fisher–Yates shuffle** (seed → CSPRNG/HMAC-DRBG
   stream → shuffle) over entries, then deal them round-robin to participants per
   the auto-balance rule; leftover-recipient selection also derives from the same
   seed stream.
4. Persist an **immutable Draw record**: `seed`, `algorithm_version`,
   `participant_order`, `entry_order`, `allocations`, `run_at`, `run_by`,
   `trigger` (scheduled/manual).
5. Expose all of the above (except nothing — the seed is public after the draw) so
   the result is **independently reproducible**.

**Algorithm versioning:** the exact shuffle/deal procedure is pinned by
`algorithm_version`; never change v1's behavior — add v2 for changes.

> **Designed-for upgrade path:** a **commit-reveal + public entropy** mode
> (publish `SHA256(seed)` before the draw, then combine with a public beacon such
> as **drand** at draw time, reveal after) is the intended stronger option for a
> later phase. The Draw schema reserves `seed_commitment`, `public_entropy_source`,
> and `public_entropy_value` fields so we can introduce it without migration pain.

---

## 7. Data Model (relational, MySQL/MariaDB)

> Rails/ActiveRecord naming. Timestamps (`created_at`, `updated_at`) on all tables.
> **Database:** MariaDB 11.x (MySQL-compatible) via the `mysql2` adapter.
>
> **Type mapping (vs. the Postgres idioms originally drafted):**
> - **UUID** — MariaDB has no native `uuid`/`gen_random_uuid`. Use a `binary(16)`
>   primary key populated by Rails (`Rails 8` supports app-generated UUIDv7 PKs), or
>   keep standard `bigint` PKs and add a separate **`public_id`** (UUID/ULID stored
>   as `char(26)`/`char(36)`) for anything exposed in URLs. **Chosen: bigint PKs +
>   a unique `public_id` (ULID) on URL-exposed models** — simplest and index-friendly.
> - **`citext`** — not available. Use a case-insensitive collation
>   (`utf8mb4_0900_ai_ci` on MySQL 8 / `utf8mb4_uca1400_ai_ci` on MariaDB) on the
>   column, or normalize to lowercase in the model + a unique index.
> - **`jsonb`** — use MariaDB's `JSON` column type (stored as validated LONGTEXT).
> - **`timestamptz`** — store UTC `datetime(6)`; keep timezone as a separate string
>   column where the organizer's local time matters (`sweepstakes.timezone`).
> - Unguessable public tokens (`share_token`, `claim_token`, `public_id`) are
>   random strings (ULID/`SecureRandom`), not DB-generated UUIDs.

### `users` (organizers & admins)
- `id` (bigint, pk) · `public_id` (ULID, unique) where exposed in URLs
- `email` (citext, unique, not null)
- `password_digest` (for has_secure_password) — nullable if OAuth-only
- `name`
- `role` (enum: `organizer`, `admin`; default `organizer`)
- `confirmed_at`, auth/OAuth fields as needed

### `sweepstakes`
- `id` (bigint, pk) · `public_id` (ULID, unique) where exposed in URLs
- `user_id` (fk → users, the organizer)
- `name` (not null)
- `description`
- `slug` / `share_token` (unguessable, unique — used in the public URL)
- `draw_at` (timestamptz, nullable until set) + `timezone`
- `status` (enum: `draft`, `open`, `locked`, `drawn`)
- `allocation_rule` (enum: `auto_balance`; reserved for future rules)
- `registration_open` (boolean)
- `max_participants` (int, nullable)
- `participants_public` (boolean, default true)
- `template_id` (fk → competition_templates, nullable — provenance only)

### `entries`
- `id` (bigint, pk) · `public_id` (ULID, unique) where exposed in URLs
- `sweepstake_id` (fk)
- `name` (not null)
- `position` (int — display/canonical order)
- `metadata` (jsonb — flag emoji, country code, group, etc.)

### `participants`
- `id` (bigint, pk) · `public_id` (ULID, unique) where exposed in URLs
- `sweepstake_id` (fk)
- `name` (not null)
- `claim_token` (unguessable, unique per sweepstake)
- `registered_ip` (for light abuse controls — see §10), `user_agent`
- **Duplicate names are allowed** (families/offices may share names). Do **not**
  add a unique constraint on `(sweepstake_id, lower(name))`; instead the register
  form shows a soft warning when an exact-match name already exists.

### `draws`
- `id` (bigint, pk) · `public_id` (ULID, unique) where exposed in URLs
- `sweepstake_id` (fk, unique while a single active draw — historical draws kept)
- `seed` (text), `algorithm_version` (int)
- `participant_order` (jsonb — array of participant ids)
- `entry_order` (jsonb — array of entry ids)
- `run_at`, `run_by` (fk users, nullable for scheduled), `trigger` (enum)
- reserved: `seed_commitment`, `public_entropy_source`, `public_entropy_value`

### `allocations`
- `id` (bigint, pk) · `public_id` (ULID, unique) where exposed in URLs
- `draw_id` (fk), `participant_id` (fk), `entry_id` (fk)
- unique index `(draw_id, entry_id)` — every entry assigned at most once.

### `competition_templates` & `template_entries`
- `competition_templates`: `id`, `name`, `slug`, `category`, `year/season`,
  `status`, `version`.
- `template_entries`: `id`, `competition_template_id` (fk), `name`, `position`,
  `metadata` (jsonb).

---

## 8. API (Rails, JSON, versioned `/api/v1`)

REST + JSON. Auth via **JWT bearer** (or Rails session cookies if SPA is
same-origin — see §9). Public participant endpoints are unauthenticated but
gated by the sweepstake `share_token`.

### Auth
- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `DELETE /api/v1/auth/logout`
- `GET  /api/v1/me`
- OAuth callbacks (later/optional): `/api/v1/auth/:provider/callback`

### Organizer — sweepstakes (auth required)
- `GET    /api/v1/sweepstakes` — list mine
- `POST   /api/v1/sweepstakes` — create (optionally `template_id`)
- `GET    /api/v1/sweepstakes/:id`
- `PATCH  /api/v1/sweepstakes/:id`
- `DELETE /api/v1/sweepstakes/:id`
- `POST   /api/v1/sweepstakes/:id/lock` — close registration
- `POST   /api/v1/sweepstakes/:id/draw` — run draw now (manual/early)
- `POST   /api/v1/sweepstakes/:id/reset_draw` — clears allocations, reopens (logged)
- Entries: `GET/POST /api/v1/sweepstakes/:id/entries`,
  `PATCH/DELETE /api/v1/entries/:id`, `POST .../entries/bulk` (paste list)
- Participants (manage): `GET /api/v1/sweepstakes/:id/participants`,
  `DELETE /api/v1/participants/:id`

### Public — share page (no auth; identified by `share_token`)
- `GET  /api/v1/s/:share_token` — public sweepstake view (name, host, draw date,
  status, entry count, participant list if `participants_public`, results if drawn)
- `POST /api/v1/s/:share_token/register` — `{ name }` → returns `{ claim_token }`
- `GET  /api/v1/s/:share_token/me?claim_token=…` — my registration + allocation
- `GET  /api/v1/s/:share_token/verification` — seed, orders, algorithm version

### Templates
- `GET /api/v1/templates` — published templates (for the create form)
- `GET /api/v1/templates/:slug`
- Admin: `POST/PATCH/DELETE /api/v1/admin/templates…`

> **Conventions:** JSON:API-ish or simple flat JSON (pick one and be consistent);
> snake_case keys; ISO 8601 timestamps with timezone; pagination on list
> endpoints; consistent error envelope `{ "errors": [{ "code", "detail", "field" }] }`.

---

## 9. Tech Stack & Architecture

### 9.1 Backend — Ruby on Rails (API-only)
- **Rails 8.1**, `--api` mode, **Ruby 3.4** (actual installed toolchain).
- **MariaDB 11.x** (MySQL-compatible) via the `mysql2` adapter. See §7 for the
  type mapping (JSON columns, case-insensitive collations, ULID `public_id`s).
- **Background jobs:** **Solid Queue** (Rails 8 default, DB-backed — no Redis).
  Scheduled draws run via Solid Queue's recurring/scheduled jobs, or a job enqueued
  to fire at `draw_at`. (Sidekiq+Redis is no longer needed; revisit only if job
  volume demands it.)
- **Cache:** Solid Cache (Rails 8 default, DB-backed).
- **Auth:** `has_secure_password` (bcrypt). Token auth with JWT for the SPA;
  consider Rails session cookies if same-origin. OAuth (Google) optional via
  OmniAuth in a later phase.
- **Authorization:** Pundit policies (organizer owns their sweepstakes; admin role
  for templates).
- **Serialization:** `jsonapi-serializer` / `alba` (pick one).
- **Validation & rate limiting:** `rack-attack` for register/login throttling.
- **Testing:** RSpec, FactoryBot, request specs for the API.

### 9.2 Frontend — React (web)
- **React 18 + TypeScript**, built with **Vite** as an SPA that consumes the Rails
  API. (Link-preview/SEO on share pages is explicitly **not** a requirement — see
  §14 — so no SSR/Next.js is needed.)
- **Routing:** React Router.
- **Data fetching/cache:** TanStack Query (React Query).
- **Forms/validation:** React Hook Form + Zod.
- **Styling/UI:** Tailwind CSS + a component lib (shadcn/ui or Radix). Mobile-first,
  responsive.
- **State:** server state via React Query; minimal local/UI state otherwise.

### 9.3 Repo & deployment
- **Monorepo** layout:
  - `/api` — Rails app (Rails 8, API-only, MySQL).
  - `/web` — React app (Vite + TypeScript, **pnpm** package manager).
  - `SPEC.md` at root; `/docs` for additional docs.
- **Local dev:** local MariaDB (already provisioned) + `bin/rails server` for the
  API and `pnpm dev` (Vite) for the web. Solid Queue runs in-process/via
  `bin/jobs`. Docker Compose optional, not required (no Redis to orchestrate).
- **Deploy:** API + MariaDB on a PaaS or containers (Kamal, the Rails 8 default,
  is a good fit); React app built by Vite to static assets on a CDN/static host
  (or served by the API). HTTPS only.
- **Env config** via `.env` / Rails credentials; never commit secrets.

### 9.4 Mobile (later phase)
- **React Native (Expo)** app reusing the same Rails API and sharing TypeScript
  types/validation (Zod schemas) and API client where practical. The API and auth
  are designed to be client-agnostic from day one (token auth, no SPA-only
  assumptions).

---

## 10. Legal, Compliance & Trust

- **Free entry, no payment, no platform-held prizes** — the software facilitates a
  random draw only. This deliberately avoids gambling/lottery licensing. A
  disclaimer states the platform does not run lotteries and any stake/prize is a
  private arrangement between participants.
- **Jurisdiction:** `.je` (Jersey). Confirm Jersey-specific requirements; default
  to GDPR-equivalent data protection (Jersey's Data Protection (Jersey) Law 2018).
- **Privacy / data minimization:** participants give only a **name**. No email or
  login required to enter. Store minimal abuse-control metadata (IP/UA) with a
  short retention window; document retention in a privacy policy.
- **Consent & visibility:** make clear on the register form that the entered name
  will be **publicly visible** to anyone with the link (if `participants_public`).
- **Terms of Service + Privacy Policy** pages required before public launch.
- **Right to erasure:** organizers can delete participants; provide a path to
  delete a sweepstake and all its data.

---

## 11. Screens (Web)

**Public**
- **Landing / marketing** — what it is, "Create a sweepstake" CTA.
- **Share page** (`/s/:token`) — host, name, **countdown to draw**, entry count,
  **registrant list**, register form; **results view** once drawn (all
  allocations; viewer's own highlighted); **verification** link/panel.

**Organizer (auth)**
- **Auth** — sign up, log in, forgot password.
- **Dashboard** — my sweepstakes (status, draw date, participant count, quick
  actions).
- **Create / edit sweepstake** — name, date/timezone, template-or-manual entries,
  options.
- **Manage sweepstake** — entries editor, registrant list (remove), share link &
  QR, "Lock registration", "Run draw now", post-draw results, "Reset draw".
- **Account settings.**

**Platform Admin**
- **Templates manager** — CRUD competitions and their entries; publish/archive.
- **Platform metrics** (basic).

---

## 12. Milestones / Phased Delivery

**Phase 0 — Foundations**
- Monorepo, dev setup, CI, Rails API skeleton, React (Vite/pnpm) app skeleton,
  MariaDB schema + migrations, auth (signup/login/me), Pundit.

**Phase 1 — Core sweepstake (MVP of the real product)**
- Create sweepstake (manual entries), share link, public share page, participant
  registration (name + claim token), live registrant list, draw date + countdown.

**Phase 2 — The draw**
- Auto-balance allocation, auditable seeded shuffle, immutable Draw + allocations,
  manual "Run draw now," scheduled auto-draw via Solid Queue, results view,
  verification panel + public algorithm doc.

**Phase 3 — Templates**
- Competition templates (World Cup 2026 + starter set), template picker in create
  flow, admin template CRUD.

**Phase 4 — Production hardening**
- Rate limiting, validation polish, ToS/Privacy, error/empty/loading states,
  accessibility pass, observability/logging, backups, deploy pipeline.

**Phase 5 — Later**
- Email notifications (draw run, results), OAuth login, stronger commit-reveal +
  public-entropy fairness mode, additional allocation rules (1:1, organizer-choice),
  React Native (Expo) mobile app, live competition results integration.

---

## 13. Non-Functional Requirements

- **Security:** HTTPS only; CSRF/CORS configured for SPA; bcrypt passwords;
  unguessable tokens (share_token, claim_token) with high entropy; parameterized
  queries (ActiveRecord); rate limiting on register/login; secrets via env/credentials.
- **Performance:** share page loads fast and handles bursty registration (link
  shared to a group). Index hot paths (`share_token`, `sweepstake_id`).
- **Reliability:** draw is transactional and idempotent; scheduled jobs retried
  safely without double-drawing (guard on `status`).
- **Accessibility:** WCAG 2.1 AA target; keyboard-navigable; semantic markup.
- **Observability:** structured logs, error tracking (e.g. Sentry), basic metrics.
- **i18n-ready:** copy externalized; en-GB default (it's `.je`).
- **Testing:** request specs for every API endpoint; a dedicated, deterministic
  test for the draw algorithm proving reproducibility from a fixed seed.

---

## 14. Resolved Decisions

1. **Duplicate participant names** — **Allowed**, with a soft warning on exact
   match. No unique constraint. (§7)
2. **Editing entries after registration opens** — **Allowed until the draw runs;**
   recompute allocation counts in the UI as entries change. Only the draw locks them.
3. **Template starter set** — **World Cup 2026 only** at launch. Others later. (§5)
4. **Share-page SEO/OG link previews** — **Not a concern.** Stay with the Vite SPA;
   no SSR/prerender shim.
5. **Result notifications** — **On-page only** in v1. Participants return via their
   link/claim token to view results; no email collected. (Optional email is a
   later-phase consideration.)

### Still deferred (out of scope for v1)
- **Organizer monetization** — none in v1; revisit (premium templates, branding)
  later.
```
