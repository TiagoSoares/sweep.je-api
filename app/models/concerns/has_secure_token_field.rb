# Generates an opaque, high-entropy bearer token for a column before creation.
# Used for share_token / claim_token — credentials whose secrecy gates access.
#
# Unlike ULIDs (which embed a timestamp and only 80 random bits), these are
# 192-bit, URL-safe, and reveal nothing about when the record was created.
module HasSecureTokenField
  extend ActiveSupport::Concern

  TOKEN_BYTES = 24 # 24 bytes -> 192 bits -> 32 url-safe chars

  class_methods do
    # secure_token_field :share_token
    def secure_token_field(attribute)
      before_validation -> { self[attribute] ||= self.class.generate_secure_token }, on: :create
      validates attribute, presence: true, uniqueness: true
    end

    def generate_secure_token
      SecureRandom.urlsafe_base64(TOKEN_BYTES)
    end
  end
end
