require "rails_helper"

RSpec.describe "Api::V1 predictions", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "defining prediction questions on create" do
    it "stores prediction_fields passed in" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "WC", prediction_fields: ["Golden Ball", "Golden Boot"] } },
           headers: headers
      expect(response).to have_http_status(:created)
      expect(json.dig("sweepstake", "prediction_fields")).to eq(["Golden Ball", "Golden Boot"])
    end

    it "inherits the template's prediction questions when none are given" do
      create(:competition_template, :with_entries, slug: "wc-2026",
             prediction_fields: ["Golden Ball", "Golden Boot", "Golden Glove"])
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "Office WC", template_slug: "wc-2026" } },
           headers: headers
      expect(json.dig("sweepstake", "prediction_fields")).to eq(["Golden Ball", "Golden Boot", "Golden Glove"])
    end

    it "trims, de-dupes and drops blanks" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "WC", prediction_fields: [" Golden Ball ", "Golden Ball", "", "Golden Boot"] } },
           headers: headers
      expect(json.dig("sweepstake", "prediction_fields")).to eq(["Golden Ball", "Golden Boot"])
    end
  end

  describe "answering predictions at registration" do
    let(:sweepstake) do
      create(:sweepstake, prediction_fields: ["Golden Ball", "Golden Boot", "Golden Glove"])
    end

    it "saves answers for the known questions" do
      post "/api/v1/s/#{sweepstake.share_token}/register", params: {
        participant: {
          name: "Bob",
          predictions: { "Golden Ball" => "Mbappé", "Golden Boot" => "Haaland", "Golden Glove" => "Donnarumma" }
        }
      }
      expect(response).to have_http_status(:created)
      expect(json.dig("participant", "predictions")).to eq(
        "Golden Ball" => "Mbappé", "Golden Boot" => "Haaland", "Golden Glove" => "Donnarumma"
      )
    end

    it "ignores answers to unknown questions and blank answers" do
      post "/api/v1/s/#{sweepstake.share_token}/register", params: {
        participant: { name: "Bob", predictions: { "Golden Ball" => "Messi", "Hacker Field" => "x", "Golden Boot" => "  " } }
      }
      expect(json.dig("participant", "predictions")).to eq("Golden Ball" => "Messi")
    end

    it "registers fine with no predictions" do
      post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "Bob" } }
      expect(response).to have_http_status(:created)
      expect(json.dig("participant", "predictions")).to eq({})
    end
  end

  describe "predictions in public views and results" do
    let(:sweepstake) { create(:sweepstake, :with_entries, prediction_fields: ["Golden Ball"]) }

    it "exposes the questions and participants' answers on the share page" do
      create(:participant, sweepstake: sweepstake, name: "Carol", predictions: { "Golden Ball" => "Bellingham" })
      get "/api/v1/s/#{sweepstake.share_token}"
      expect(json.dig("sweepstake", "prediction_fields")).to eq(["Golden Ball"])
      expect(json.dig("sweepstake", "participants", 0, "predictions")).to eq("Golden Ball" => "Bellingham")
    end

    it "includes predictions in the drawn results" do
      p = create(:participant, sweepstake: sweepstake, predictions: { "Golden Ball" => "Vinicius" })
      DrawRunner.new(sweepstake.reload, run_by: sweepstake.user).call
      get "/api/v1/s/#{sweepstake.share_token}/results"
      row = json["results"].find { |r| r["participant_id"] == p.public_id }
      expect(row["predictions"]).to eq("Golden Ball" => "Vinicius")
    end
  end
end
