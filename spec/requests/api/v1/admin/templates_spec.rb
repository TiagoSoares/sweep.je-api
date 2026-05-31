require "rails_helper"

RSpec.describe "Api::V1::Admin::Templates", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:admin) { create(:admin) }
  let(:admin_headers) { auth_headers(admin) }

  describe "authorization" do
    it "forbids non-admins" do
      get "/api/v1/admin/templates", headers: auth_headers(create(:user))
      expect(response).to have_http_status(:forbidden)
    end

    it "requires authentication" do
      get "/api/v1/admin/templates"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/admin/templates" do
    it "creates a template with entries" do
      post "/api/v1/admin/templates",
           params: { template: { name: "Euro 2028", slug: "euro-2028", category: "football",
                                  year: 2028, status: "published",
                                  entries: ["England", "France", "Spain"] } },
           headers: admin_headers

      expect(response).to have_http_status(:created)
      expect(json.dig("template", "entries").size).to eq(3)
    end

    it "rejects an invalid slug" do
      post "/api/v1/admin/templates",
           params: { template: { name: "Bad", slug: "Not A Slug" } },
           headers: admin_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/admin/templates/:slug" do
    it "replaces entries when an entries array is given" do
      template = create(:competition_template, :with_entries, slug: "wc-2026", entries_count: 4)

      patch "/api/v1/admin/templates/wc-2026",
            params: { template: { entries: ["A", "B"] } },
            headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(template.reload.template_entries.pluck(:name)).to eq(%w[A B])
    end

    it "can archive a template (hiding it from the public list)" do
      create(:competition_template, slug: "old", status: :published)
      patch "/api/v1/admin/templates/old", params: { template: { status: "archived" } }, headers: admin_headers
      expect(json.dig("template", "status")).to eq("archived")
    end
  end

  describe "DELETE /api/v1/admin/templates/:slug" do
    it "deletes a template" do
      create(:competition_template, slug: "gone")
      expect { delete "/api/v1/admin/templates/gone", headers: admin_headers }
        .to change(CompetitionTemplate, :count).by(-1)
    end
  end
end
