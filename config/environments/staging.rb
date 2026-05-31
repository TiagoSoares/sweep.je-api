# Staging mirrors production exactly. Differences come from environment
# variables (DB_NAME defaults to sweep_staging, APP_HOSTS, FRONTEND_ORIGINS,
# secrets, TRUSTED_PROXIES) — not from code — so staging is a faithful
# pre-production environment.
#
# Loading production.rb runs its `Rails.application.configure` block (eager
# loading, SSL/HSTS, host authorization, Solid Queue/Cache wiring, etc.).
require_relative "production"

Rails.application.configure do
  # Staging-specific overrides go here. None needed yet — keep it identical to
  # production. (To allow plain HTTP on staging, you could set
  # `config.force_ssl = false` here, but staging should normally use TLS too.)
end
