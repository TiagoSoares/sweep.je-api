# Rate limiting (§9.1, §13). Throttles abuse-prone endpoints and applies a
# blanket cap to everything else. Tunable via env; disabled automatically in tests.
#
# NOTE: throttling keys on `req.ip`, which Rails derives from X-Forwarded-For.
# Behind a proxy/load balancer you MUST set the real client IP correctly, or an
# attacker can spoof the header to dodge throttles. Set TRUSTED_PROXIES (CIDR,
# comma-separated) so ActionDispatch::RemoteIp trusts only your proxy.
class Rack::Attack
  # Allow health checks straight through.
  safelist("health") { |req| req.path == "/up" }

  # Blanket cap: no single IP may exceed this many requests across the whole API.
  # Catches token enumeration (e.g. hammering /s/:token), scraping, and floods.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Login attempts by IP (brute-force protection).
  throttle("auth/login/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Login attempts by email (credential stuffing across rotating IPs).
  throttle("auth/login/email", limit: 10, period: 5.minutes) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      email = extract_login_email(req)
      email.presence
    end
  end

  # Signups by IP.
  throttle("auth/signup/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/signup" && req.post?
  end

  # Participant registrations by IP. Generous (a real group registers in bursts)
  # but enough to stop runaway spam.
  throttle("participants/register/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/api/v1/s/[^/]+/register\z})
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]
    headers = { "Content-Type" => "application/json" }
    headers["Retry-After"] = retry_after.to_s if retry_after
    body = { errors: [{ code: "rate_limited", detail: "Too many requests. Please slow down." }] }.to_json
    [429, headers, [body]]
  end

  # Safely pull the login email out of the request body for keying.
  def self.extract_login_email(req)
    body = req.body.read
    req.body.rewind
    return if body.blank?

    JSON.parse(body).dig("user", "email").to_s.strip.downcase
  rescue JSON::ParserError
    nil
  end
end

# Don't rate-limit the test suite.
Rack::Attack.enabled = !Rails.env.test?
