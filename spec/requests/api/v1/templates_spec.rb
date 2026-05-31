require "rails_helper"

RSpec.describe "Api::V1 Templates", type: :request do
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/templates" do
    it "lists published templates only" do
      create(:competition_template, :with_entries, name: "World Cup 2026", slug: "wc-2026")
      create(:competition_template, status: :draft, slug: "hidden")

      get "/api/v1/templates"

      expect(response).to have_http_status(:ok)
      slugs = json["templates"].map { |t| t["slug"] }
      expect(slugs).to include("wc-2026")
      expect(slugs).not_to include("hidden")
      expect(json["templates"].find { |t| t["slug"] == "wc-2026" }["entries_count"]).to eq(4)
    end
  end

  describe "GET /api/v1/templates/:slug" do
    it "returns the template with its entries" do
      create(:competition_template, :with_entries, slug: "euro-2024", entries_count: 3)
      get "/api/v1/templates/euro-2024"
      expect(response).to have_http_status(:ok)
      expect(json.dig("template", "entries").size).to eq(3)
    end

    it "404s for a draft template" do
      create(:competition_template, status: :draft, slug: "secret")
      get "/api/v1/templates/secret"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "creating a sweepstake from a template" do
    let(:user) { create(:user) }
    let(:headers) { auth_headers(user) }

    it "copies the template's entries onto the new sweepstake" do
      create(:competition_template, :with_entries, slug: "wc-2026", entries_count: 8)

      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "Office WC", template_slug: "wc-2026" } },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json.dig("sweepstake", "entries_count")).to eq(8)
    end

    it "lets explicit entries override the template's while keeping provenance" do
      template = create(:competition_template, :with_entries, slug: "wc-2026", entries_count: 3)

      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "Custom", template_slug: "wc-2026", entries: ["Only This"] } },
           headers: headers

      expect(json.dig("sweepstake", "entries_count")).to eq(1)
      expect(json.dig("sweepstake", "entries").first["name"]).to eq("Only This")
      expect(Sweepstake.last.competition_template).to eq(template)
    end
  end
end
