# sweep.je

A web app for creating and running **sweepstakes** (the office/social kind):
an organizer creates a pool of entries, shares a link, people register with just
their name, and a provably-recorded random draw assigns each participant one or
more entries. See **[SPEC.md](./SPEC.md)** for the full product & technical spec.

## Monorepo layout

| Path        | What                                                              |
|-------------|------------------------------------------------------------------|
| `/api`      | Rails 8 API-only backend (Ruby 3.4, MySQL via Trilogy).          |
| `/web`      | React + TypeScript SPA (Vite, pnpm).                             |
| `SPEC.md`   | Product & technical specification.                               |
| `/docs`     | Additional docs (added as needed).                              |

## Stack

- **Backend:** Rails 8.1, API-only, Trilogy adapter → MySQL 8.4 / MariaDB.
  Jobs/cache/cable use the Rails 8 Solid* stack (DB-backed, no Redis).
  Auth = JWT bearer tokens. Authorization = Pundit. Serialization = Alba.
- **Frontend:** React 18 + TypeScript, Vite, React Router, TanStack Query,
  React Hook Form + Zod, Tailwind CSS v4.

## Prerequisites

- Ruby 3.4 + Bundler (installed)
- Node 22 LTS (installed) and **pnpm** (via corepack)
- A MySQL/MariaDB server with a `sweep` user that has privileges on all
  `sweep*` databases.

> pnpm was installed to `~/.local/bin`. Add it to your PATH:
> `export PATH="$HOME/.local/bin:$PATH"` (add to your shell profile to persist).

## Getting started

### API (port 3001)

```bash
cd api
bundle install
bin/rails db:create db:migrate   # creates sweep_development / sweep_test
bin/rails server -p 3001
```

DB credentials default to the local `sweep` user (see `config/database.yml`);
override with `DB_USERNAME` / `DB_PASSWORD` / `DB_HOST` env vars.

Run the test suite:

```bash
cd api && bundle exec rspec
```

### Web (port 5173)

```bash
cd web
pnpm install
pnpm dev        # http://localhost:5173 — proxies /api to http://localhost:3001
```

Build / type-check:

```bash
cd web && pnpm build
```

## What works today

**Phase 0 — Foundations**
- Organizer **signup / login / logout** (JWT) and **GET /api/v1/me**.
- User model with ULID `public_id`s, `has_secure_password`, role enum,
  case-insensitive unique email.
- CORS, rate limiting (rack-attack), Pundit policies, consistent JSON error
  envelope, RSpec request + model specs.

**Phase 1 — Core sweepstake**
- Organizer **CRUD for sweepstakes** with entries (manual list), auto-generated
  unguessable **share link**, and **lock registration**.
- **Entries** endpoints (add / bulk-paste / rename / delete; frozen after the draw).
- **Public share page** (no auth): host, draw countdown, live registrant list,
  and **name-only registration** issuing a per-sweepstake claim token.
- Organizer **manage** view: share link + copy, entries, registrant list, lock,
  delete. **38 RSpec examples**, all green; full flow verified end-to-end.

**Phase 2 — The draw**
- **Auto-balance allocation** over an **auditable seeded shuffle** (`SeededRandom`,
  algorithm v1) — see [docs/DRAW_VERIFICATION.md](./docs/DRAW_VERIFICATION.md).
- Immutable `Draw` + `Allocation` records storing seed, algorithm version, and
  canonical orderings; **manual "Run draw now"**, **scheduled auto-draw** at
  `draw_at` (Solid Queue `AutoDrawJob`), and **reset draw**.
- Public **results** + **reproducible verification** endpoints; organizer and
  participant **results views**, participant's own allocation highlighted, and an
  in-page **fairness verification panel**.
- **61 RSpec examples** (incl. a determinism/reproducibility proof), all green.
  Verified live: a third-party re-implementation of the algorithm reproduced a
  real draw's allocations exactly.

**Phase 3 — Templates**
- `CompetitionTemplate` + `TemplateEntry` models; **World Cup 2026 seeded** with
  all **48 teams** (flags in metadata) via `bin/rails db:seed`.
- Public **`GET /templates`** + **`/templates/:slug`**; create a sweepstake
  **from a template** (`template_slug`) which copies its entries (decoupled —
  later template edits don't affect existing draws). Manual entries override the
  template while keeping provenance.
- **Admin template CRUD** (`/api/v1/admin/templates`, admin-role only) with specs.
- Create page has a **template picker** that pre-fills the entries box.
- **73 RSpec examples**, all green.

**Admin UI**
- **Admin templates manager** (`/admin/templates`): list, create, edit, delete —
  guarded to admin-role users. An "Admin" link appears in the dashboard for admins.
- Grant admin with a rake task: **`bin/rails 'admin:grant[you@example.com]'`**
  (revoke with `admin:revoke`).

React SPA pages: landing, signup, login, dashboard, create (with template
picker), manage (draw controls + results), the public share/results page, and
the admin templates manager.

## Security

The app has had a full security audit — see **[docs/SECURITY.md](./docs/SECURITY.md)**.
Brakeman, bundler-audit, and pnpm audit are all clean; auth, authorization (IDOR),
JWT, token entropy, input limits, rate limiting, and data exposure are covered by
tests (`spec/security/`). Set the production env vars listed in SECURITY.md
(`RAILS_MASTER_KEY`, `APP_HOSTS`, `TRUSTED_PROXIES`, `FRONTEND_ORIGINS`, DB creds)
and serve over HTTPS.

## Seeding & admin

```bash
cd api
bin/rails db:seed                          # FIFA World Cup 2026 (48 teams)
bin/rails 'admin:grant[you@example.com]'   # make yourself an admin
```

Next up is **Phase 4 — production hardening** (ToS/privacy, observability,
deploy pipeline, accessibility pass) — see the milestones in [SPEC.md](./SPEC.md).
