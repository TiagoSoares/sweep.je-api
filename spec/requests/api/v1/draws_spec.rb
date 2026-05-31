require "rails_helper"

RSpec.describe "Api::V1 Draws", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  def drawable_sweepstake(owner: user)
    s = create(:sweepstake, user: owner)
    3.times { |i| create(:entry, sweepstake: s, position: i + 1) }
    2.times { create(:participant, sweepstake: s) }
    s
  end

  describe "POST /api/v1/sweepstakes/:id/draw" do
    it "runs the draw and marks it drawn" do
      s = drawable_sweepstake
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json.dig("sweepstake", "status")).to eq("drawn")
      expect(s.reload.current_draw.allocations.count).to eq(3)
    end

    it "409s when not drawable (no participants)" do
      s = create(:sweepstake, :with_entries, user: user)
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers
      expect(response).to have_http_status(:conflict)
      expect(json.dig("errors", 0, "code")).to eq("not_drawable")
    end

    it "409s when drawing twice" do
      s = drawable_sweepstake
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers
      expect(response).to have_http_status(:conflict)
    end

    it "forbids drawing someone else's sweepstake" do
      s = drawable_sweepstake(owner: create(:user))
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/sweepstakes/:id/reset_draw" do
    it "clears the draw and reopens" do
      s = drawable_sweepstake
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers
      expect { post "/api/v1/sweepstakes/#{s.public_id}/reset_draw", headers: headers }
        .to change(Draw, :count).by(-1)
        .and change(Allocation, :count).by(-3)
      expect(response).to have_http_status(:ok)
      expect(json.dig("sweepstake", "status")).to eq("open")
    end

    it "409s when there is nothing to reset" do
      s = drawable_sweepstake
      post "/api/v1/sweepstakes/#{s.public_id}/reset_draw", headers: headers
      expect(response).to have_http_status(:conflict)
    end
  end

  describe "public results and verification" do
    it "exposes results and a reproducible verification payload after the draw" do
      s = drawable_sweepstake
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers

      get "/api/v1/s/#{s.share_token}/results"
      expect(response).to have_http_status(:ok)
      results = JSON.parse(response.body)["results"]
      total = results.sum { |r| r["entries"].size }
      expect(total).to eq(3)

      get "/api/v1/s/#{s.share_token}/verification"
      v = JSON.parse(response.body)["verification"]
      expect(v["seed"]).to be_present
      expect(v["algorithm_version"]).to eq(1)
      expect(v["entry_order"].size).to eq(3)
      expect(v["allocations"].size).to eq(3)
    end

    it "returns null results before the draw" do
      s = drawable_sweepstake
      get "/api/v1/s/#{s.share_token}/results"
      expect(json["results"]).to be_nil
    end

    it "returns the participant's own entries on /me after the draw" do
      s = drawable_sweepstake
      participant = s.participants.first
      post "/api/v1/sweepstakes/#{s.public_id}/draw", headers: headers

      get "/api/v1/s/#{s.share_token}/me", params: { claim_token: participant.claim_token }
      expect(response).to have_http_status(:ok)
      expect(json["entries"]).to be_an(Array)
    end
  end
end
