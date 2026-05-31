require "rails_helper"

RSpec.describe "Api::V1 Auth", type: :request do
  let(:json) { JSON.parse(response.body) }

  describe "POST /api/v1/auth/signup" do
    let(:params) { { user: { name: "Ada Lovelace", email: "ada@example.com", password: "password123" } } }

    it "creates a user and returns a token" do
      expect { post "/api/v1/auth/signup", params: params }
        .to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["token"]).to be_present
      expect(json.dig("user", "email")).to eq("ada@example.com")
      expect(json.dig("user", "id")).to be_present
      expect(json.dig("user", "role")).to eq("organizer")
    end

    it "rejects invalid data with an error envelope" do
      post "/api/v1/auth/signup", params: { user: { name: "", email: "nope", password: "x" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to be_an(Array)
      expect(json["errors"].first).to include("detail")
    end

    it "rejects duplicate emails" do
      create(:user, email: "ada@example.com")
      post "/api/v1/auth/signup", params: params

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "grace@example.com", password: "password123") }

    it "returns a token for valid credentials" do
      post "/api/v1/auth/login", params: { user: { email: "grace@example.com", password: "password123" } }

      expect(response).to have_http_status(:ok)
      expect(json["token"]).to be_present
    end

    it "rejects bad credentials" do
      post "/api/v1/auth/login", params: { user: { email: "grace@example.com", password: "wrong" } }

      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("errors", 0, "code")).to eq("invalid_credentials")
    end
  end

  describe "GET /api/v1/me" do
    let!(:user) { create(:user) }
    let(:token) { JsonWebToken.encode({ sub: user.public_id }) }

    it "returns the current user with a valid token" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(json.dig("user", "id")).to eq(user.public_id)
    end

    it "rejects requests without a token" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("errors", 0, "code")).to eq("unauthorized")
    end
  end
end
