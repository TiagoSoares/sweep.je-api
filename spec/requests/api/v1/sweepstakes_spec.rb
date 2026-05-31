require "rails_helper"

RSpec.describe "Api::V1::Sweepstakes", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "POST /api/v1/sweepstakes" do
    let(:params) do
      {
        sweepstake: {
          name: "World Cup 2026",
          description: "Office draw",
          draw_at: 1.week.from_now.iso8601,
          timezone: "Europe/London",
          entries: ["Brazil", "England", { name: "France" }]
        }
      }
    end

    it "creates a sweepstake with entries and a share token" do
      expect { post "/api/v1/sweepstakes", params: params, headers: headers }
        .to change(Sweepstake, :count).by(1)
        .and change(Entry, :count).by(3)

      expect(response).to have_http_status(:created)
      s = json["sweepstake"]
      expect(s["name"]).to eq("World Cup 2026")
      expect(s["share_token"]).to be_present
      expect(s["status"]).to eq("open")
      expect(s["entries_count"]).to eq(3)
      expect(s["entries"].map { |e| e["name"] }).to contain_exactly("Brazil", "England", "France")
    end

    it "rejects an unnamed sweepstake" do
      post "/api/v1/sweepstakes", params: { sweepstake: { name: "" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires authentication" do
      post "/api/v1/sweepstakes", params: params
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/sweepstakes" do
    it "lists only the current user's sweepstakes" do
      create_list(:sweepstake, 2, user: user)
      create(:sweepstake) # someone else's

      get "/api/v1/sweepstakes", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["sweepstakes"].size).to eq(2)
    end
  end

  describe "GET /api/v1/sweepstakes/:id" do
    let(:sweepstake) { create(:sweepstake, :with_entries, user: user) }

    it "returns the sweepstake to its owner" do
      get "/api/v1/sweepstakes/#{sweepstake.public_id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json.dig("sweepstake", "id")).to eq(sweepstake.public_id)
    end

    it "forbids access to another organizer's sweepstake" do
      other = create(:sweepstake)
      get "/api/v1/sweepstakes/#{other.public_id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/sweepstakes/:id/lock" do
    let(:sweepstake) { create(:sweepstake, user: user) }

    it "locks registration" do
      post "/api/v1/sweepstakes/#{sweepstake.public_id}/lock", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json.dig("sweepstake", "status")).to eq("locked")
      expect(json.dig("sweepstake", "registration_open")).to be(false)
    end
  end

  describe "DELETE /api/v1/sweepstakes/:id" do
    let!(:sweepstake) { create(:sweepstake, :with_entries, user: user) }

    it "deletes the sweepstake and its entries" do
      expect { delete "/api/v1/sweepstakes/#{sweepstake.public_id}", headers: headers }
        .to change(Sweepstake, :count).by(-1)
        .and change(Entry, :count).by(-8)
      expect(response).to have_http_status(:no_content)
    end
  end
end
