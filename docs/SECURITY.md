# Security

This document records the security posture of sweep.je and the hardening pass
performed on the codebase.

## Automated scanning

| Tool | Scope | Result |
|------|-------|--------|
| **Brakeman** | Rails static analysis (SQLi, XSS, mass-assignment, etc.) | 0 warnings |
| **bundler-audit** | Ruby gem CVEs | 0 vulnerabilities |
| **pnpm audit** | Frontend dependency CVEs | 0 vulnerabilities |

Run them anytime:

```bash
cd api && bundle exec brakeman && bundle exec bundle-audit check --update
cd web && pnpm audit
```

## Findings fixed in the hardening pass

| # | Severity | Finding | Fix |
|---|----------|---------|-----|
| 1 | **Critical** | `rails new --skip-git` left the API with **no `.gitignore`**, so `config/master.key` and `database.yml` would be committed on first `git add`. (Nothing was committed yet — caught before exposure.) | Added a complete `api/.gitignore` ignoring `master.key`, `.env`, logs, tmp, storage. |
| 2 | High | DB password was **hardcoded** as a fallback in `database.yml`. | Removed; credentials now come from the environment only, loaded in dev from a git-ignored `.env` via `dotenv-rails`. No secret default. |
| 3 | High | `force_ssl` / `assume_ssl` disabled in production → tokens could travel over cleartext HTTP. | Enabled (HSTS, https redirect, secure cookies). |
| 4 | Medium | No Host-header / DNS-rebinding protection. | `config.hosts` set from `APP_HOSTS` in production. |
| 5 | Medium | `share_token` / `claim_token` used **ULIDs** (predictable timestamp prefix, 80 random bits). | Switched to opaque `SecureRandom.urlsafe_base64(24)` (192-bit) tokens. `public_id` stays ULID (non-secret identifier). |
| 6 | Medium | No length limits on user-supplied strings (names, description). | Added length validations across all models. |
| 7 | Medium | `entries` arrays were unbounded (memory/DB exhaustion). | Capped at `Sweepstake::MAX_ENTRIES` (500) on create and bulk. |
| 8 | Medium | Rate limiting only covered auth/register; everything else was open. | Added a blanket per-IP throttle and a per-account login throttle (credential stuffing). |
| 9 | Medium | `X-Forwarded-For` could be spoofed to dodge IP throttles. | `TRUSTED_PROXIES` configures `action_dispatch.trusted_proxies` in production. |
| 10 | Low | `me` lookup accepted array/typed `claim_token` params. | Coerced to string. |

## Controls already in place (verified)

- **Auth:** bcrypt via `has_secure_password`; JWT with the algorithm **pinned to
  HS256** and verified (rejects `alg=none` and wrong-secret/expired tokens —
  covered by tests).
- **Authorization:** Pundit policies; every organizer resource is scoped to
  `current_user` (no IDOR — cross-tenant read/update/draw/delete return 404/403,
  covered by tests). Admin endpoints require the admin role.
- **Injection:** all DB access is via parameterized ActiveRecord; Brakeman finds
  no SQLi. No `eval`/`send`-on-user-input/`dangerouslySetInnerHTML`.
- **Data exposure:** public serializers never emit `share_token`, `claim_token`,
  organizer email, or the draw seed before the draw (covered by tests). Internal
  bigint PKs are never exposed — only ULID `public_id`s.
- **CORS:** origin allowlist from `FRONTEND_ORIGINS` (never `*`); no cookie
  credentials (bearer-token auth, so no CSRF surface).
- **Errors:** consistent envelope, generic messages, no stack traces in
  production; login returns a generic "invalid email or password".
- **Randomness:** the draw seed uses `SecureRandom` (CSPRNG); the draw is
  reproducible and independently verifiable (see `DRAW_VERIFICATION.md`).

## Required production environment

Set these as real environment variables (never in a committed file):

- `RAILS_MASTER_KEY` — decrypts credentials.
- `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_NAME`.
- `FRONTEND_ORIGINS` — exact SPA origins.
- `APP_HOSTS` — allowed Host headers.
- `TRUSTED_PROXIES` — your load balancer's IP/CIDR.
- Serve only over HTTPS (enforced by `force_ssl`).

## Known limitations / accepted risk

- **JWTs are not individually revocable** (stateless, 7-day expiry). A stolen
  token is valid until expiry. A future phase can add token versioning / a
  denylist if needed.
- **SPA stores the auth token in `localStorage`** (standard for token APIs).
  This is safe as long as the app stays XSS-free (React escapes by default and
  there are no HTML-injection sinks). An httpOnly-cookie scheme would trade this
  for CSRF complexity.
