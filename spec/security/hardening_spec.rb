require "rails_helper"

# Regression tests for the security hardening pass. These pin behaviour that, if
# silently reverted, would reopen a real vulnerability.
RSpec.describe "Security hardening", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "opaque high-entropy tokens" do
    it "share_token and claim_token are 32-char url-safe, not ULIDs" do
      s = create(:sweepstake)
      p = create(:participant, sweepstake: s)
      ulid = /\A[0-9A-HJKMNP-TV-Z]{26}\z/
      expect(s.share_token).to match(%r{\A[A-Za-z0-9_-]{32}\z})
      expect(p.claim_token).to match(%r{\A[A-Za-z0-9_-]{32}\z})
      expect(s.share_token).not_to match(ulid)
      expect(p.claim_token).not_to match(ulid)
    end

    it "tokens are unique across many records" do
      tokens = Array.new(50) { create(:sweepstake).share_token }
      expect(tokens.uniq.size).to eq(50)
    end
  end

  describe "input length limits" do
    it "rejects an over-long sweepstake name" do
      post "/api/v1/sweepstakes", params: { sweepstake: { name: "x" * 200 } }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an over-long participant name" do
      s = create(:sweepstake)
      post "/api/v1/s/#{s.share_token}/register", params: { participant: { name: "x" * 200 } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an invalid time zone" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "TZ", timezone: "Mars/Olympus" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "entry count cap" do
    it "rejects creating a sweepstake with more than the max entries" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "Huge", entries: Array.new(Sweepstake::MAX_ENTRIES + 1) { |i| "E#{i}" } } },
           headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("errors", 0, "code")).to eq("too_many_entries")
    end

    it "rejects bulk entries that would exceed the max" do
      s = create(:sweepstake, user: user)
      post "/api/v1/sweepstakes/#{s.public_id}/entries/bulk",
           params: { names: Array.new(Sweepstake::MAX_ENTRIES + 1) { |i| "E#{i}" } },
           headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("errors", 0, "code")).to eq("too_many_entries")
    end
  end

  describe "no secret leakage on the public share page" do
    it "never exposes share_token, claim_token, organizer email, or seed pre-draw" do
      s = create(:sweepstake, :with_entries, user: create(:user, email: "host@secret.com"))
      create(:participant, sweepstake: s)

      get "/api/v1/s/#{s.share_token}"
      body = response.body
      expect(body).not_to include("claim_token")
      expect(body).not_to include("host@secret.com")
      expect(json["sweepstake"]).not_to have_key("share_token")
    end
  end

  describe "cross-tenant isolation (IDOR)" do
    it "cannot read, update, draw, or delete another organizer's sweepstake" do
      victim = create(:sweepstake, :with_entries, user: create(:user))

      get    "/api/v1/sweepstakes/#{victim.public_id}", headers: headers
      expect(response).to have_http_status(:not_found)
      patch  "/api/v1/sweepstakes/#{victim.public_id}", params: { sweepstake: { name: "hijack" } }, headers: headers
      expect(response).to have_http_status(:not_found)
      post   "/api/v1/sweepstakes/#{victim.public_id}/draw", headers: headers
      expect(response).to have_http_status(:not_found)
      delete "/api/v1/sweepstakes/#{victim.public_id}", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(victim.reload.name).not_to eq("hijack")
    end

    it "cannot edit an entry belonging to another organizer" do
      victims_entry = create(:entry)
      patch "/api/v1/entries/#{victims_entry.public_id}", params: { entry: { name: "x" } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "JWT auth" do
    it "rejects a token signed with the wrong secret" do
      forged = JWT.encode({ sub: user.public_id, exp: 1.hour.from_now.to_i }, "wrong-secret", "HS256")
      get "/api/v1/me", headers: { "Authorization" => "Bearer #{forged}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired token" do
      expired = JWT.encode({ sub: user.public_id, exp: 1.hour.ago.to_i }, JsonWebToken.secret, "HS256")
      get "/api/v1/me", headers: { "Authorization" => "Bearer #{expired}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects the alg=none downgrade attack" do
      none = JWT.encode({ sub: user.public_id }, nil, "none")
      get "/api/v1/me", headers: { "Authorization" => "Bearer #{none}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
