# Helper to build an Authorization header for request specs.
module AuthHelpers
  def auth_headers(user)
    token = JsonWebToken.encode({ sub: user.public_id })
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
