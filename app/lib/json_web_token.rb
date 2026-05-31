# Thin wrapper around the `jwt` gem for issuing/verifying organizer auth tokens.
# Secret comes from Rails credentials (`jwt_secret`) and falls back to the app's
# secret_key_base so the app boots in development without extra setup.
module JsonWebToken
  ALGORITHM = "HS256".freeze
  DEFAULT_TTL = 7.days

  module_function

  def secret
    Rails.application.credentials.jwt_secret.presence ||
      Rails.application.secret_key_base
  end

  def encode(payload, ttl: DEFAULT_TTL)
    claims = payload.merge(exp: ttl.from_now.to_i)
    JWT.encode(claims, secret, ALGORITHM)
  end

  def decode(token)
    payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
    payload.with_indifferent_access
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
