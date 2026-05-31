require "rails_helper"

RSpec.describe "Api::V1::Public::Shares", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:sweepstake) { create(:sweepstake, :with_entries, user: create(:user, name: "Host McHost")) }

  describe "GET /api/v1/s/:share_token" do
    it "returns the public view without leaking secrets" do
      create(:participant, sweepstake:, name: "Alice")

      get "/api/v1/s/#{sweepstake.share_token}"

      expect(response).to have_http_status(:ok)
      s = json["sweepstake"]
      expect(s["name"]).to eq(sweepstake.name)
      expect(s["host_name"]).to eq("Host McHost")
      expect(s["entries_count"]).to eq(8)
      expect(s["participants"].map { |p| p["name"] }).to include("Alice")
      expect(s).not_to have_key("share_token")
      expect(response.body).not_to include("claim_token")
    end

    it "hides participant names when the list is private" do
      sweepstake.update!(participants_public: false)
      create(:participant, sweepstake:, name: "Alice")

      get "/api/v1/s/#{sweepstake.share_token}"

      expect(json.dig("sweepstake", "participants")).to eq([])
      expect(json.dig("sweepstake", "participants_count")).to eq(1)
    end

    it "404s for an unknown token" do
      get "/api/v1/s/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/s/:share_token/register" do
    it "registers a participant and returns a claim token" do
      expect { post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "Bob" } } }
        .to change(Participant, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["claim_token"]).to be_present
      expect(json.dig("participant", "name")).to eq("Bob")
    end

    it "rejects a blank name" do
      post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "  " } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses registration once locked" do
      sweepstake.update!(status: :locked)
      post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "Bob" } }
      expect(response).to have_http_status(:conflict)
      expect(json.dig("errors", 0, "code")).to eq("registration_closed")
    end

    it "refuses registration once full" do
      sweepstake.update!(max_participants: 1)
      create(:participant, sweepstake:)
      post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "Bob" } }
      expect(response).to have_http_status(:conflict)
    end
  end

  describe "GET /api/v1/s/:share_token/me" do
    let!(:participant) { create(:participant, sweepstake:, name: "Carol") }

    it "returns the caller's registration by claim token" do
      get "/api/v1/s/#{sweepstake.share_token}/me", params: { claim_token: participant.claim_token }
      expect(response).to have_http_status(:ok)
      expect(json.dig("participant", "name")).to eq("Carol")
    end

    it "404s for a bad claim token" do
      get "/api/v1/s/#{sweepstake.share_token}/me", params: { claim_token: "nope" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
