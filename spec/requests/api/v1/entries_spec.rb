require "rails_helper"

RSpec.describe "Api::V1::Entries", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:sweepstake) { create(:sweepstake, user: user) }

  describe "POST /api/v1/sweepstakes/:sweepstake_id/entries" do
    it "adds an entry" do
      expect { post "/api/v1/sweepstakes/#{sweepstake.public_id}/entries", params: { entry: { name: "Brazil" } }, headers: headers }
        .to change { sweepstake.entries.count }.by(1)
      expect(response).to have_http_status(:created)
      expect(json.dig("entry", "name")).to eq("Brazil")
    end
  end

  describe "POST /api/v1/sweepstakes/:sweepstake_id/entries/bulk" do
    it "adds many entries from a list" do
      expect { post "/api/v1/sweepstakes/#{sweepstake.public_id}/entries/bulk", params: { names: ["Brazil", "England", "France"] }, headers: headers }
        .to change { sweepstake.entries.count }.by(3)
      expect(response).to have_http_status(:created)
      expect(json["entries"].map { |e| e["position"] }).to eq([1, 2, 3])
    end
  end

  describe "PATCH /api/v1/entries/:id" do
    let(:entry) { create(:entry, sweepstake: sweepstake, name: "Brasil") }

    it "renames an entry" do
      patch "/api/v1/entries/#{entry.public_id}", params: { entry: { name: "Brazil" } }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(entry.reload.name).to eq("Brazil")
    end

    it "forbids editing another organizer's entry" do
      other = create(:entry)
      patch "/api/v1/entries/#{other.public_id}", params: { entry: { name: "X" } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/entries/:id" do
    let!(:entry) { create(:entry, sweepstake: sweepstake) }

    it "removes an entry" do
      expect { delete "/api/v1/entries/#{entry.public_id}", headers: headers }
        .to change(Entry, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "refuses to edit entries after the draw" do
      sweepstake.update!(status: :drawn)
      delete "/api/v1/entries/#{entry.public_id}", headers: headers
      expect(response).to have_http_status(:conflict)
    end
  end
end
