require "rails_helper"

RSpec.describe "Api::V1 multiple entries", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "configuring the toggle on the sweepstake" do
    it "defaults to false" do
      post "/api/v1/sweepstakes", params: { sweepstake: { name: "WC" } }, headers: headers
      expect(response).to have_http_status(:created)
      expect(json.dig("sweepstake", "allow_multiple_entries")).to be(false)
    end

    it "stores the flag when enabled" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "WC", allow_multiple_entries: true } },
           headers: headers
      expect(json.dig("sweepstake", "allow_multiple_entries")).to be(true)
    end

    it "can be toggled on update" do
      sweepstake = create(:sweepstake, user: user, allow_multiple_entries: false)
      patch "/api/v1/sweepstakes/#{sweepstake.public_id}",
            params: { sweepstake: { allow_multiple_entries: true } }, headers: headers
      expect(json.dig("sweepstake", "allow_multiple_entries")).to be(true)
    end

    it "is exposed on the public share page" do
      sweepstake = create(:sweepstake, :with_entries, allow_multiple_entries: true)
      get "/api/v1/s/#{sweepstake.share_token}"
      expect(json.dig("sweepstake", "allow_multiple_entries")).to be(true)
    end
  end

  describe "registering with a quantity" do
    context "when multiple entries are allowed" do
      let(:sweepstake) { create(:sweepstake, :with_entries, allow_multiple_entries: true) }

      it "creates the requested number of participant rows" do
        expect {
          post "/api/v1/s/#{sweepstake.share_token}/register",
               params: { participant: { name: "Bob" }, quantity: 3 }
        }.to change(Participant, :count).by(3)

        expect(response).to have_http_status(:created)
        expect(json["count"]).to eq(3)
        expect(json["claim_token"]).to be_present
        expect(sweepstake.participants.where(name: "Bob").count).to eq(3)
      end

      it "copies the predictions onto every entry" do
        sweepstake.update!(prediction_fields: ["Golden Boot"])
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "Bob", predictions: { "Golden Boot" => "Kane" } }, quantity: 2 }
        answers = sweepstake.participants.where(name: "Bob").map(&:predictions)
        expect(answers).to eq([{ "Golden Boot" => "Kane" }, { "Golden Boot" => "Kane" }])
      end

      it "clamps to the per-registration cap" do
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "Bob" }, quantity: 999 }
        expect(json["count"]).to eq(Sweepstake::MAX_ENTRIES_PER_REGISTRATION)
      end

      it "clamps to the remaining capacity" do
        sweepstake.update!(max_participants: 2)
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "Bob" }, quantity: 5 }
        expect(json["count"]).to eq(2)
      end

      it "treats a missing/zero quantity as one entry" do
        expect {
          post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "Bob" } }
        }.to change(Participant, :count).by(1)
        expect(json["count"]).to eq(1)
      end
    end

    context "when multiple entries are NOT allowed" do
      let(:sweepstake) { create(:sweepstake, :with_entries, allow_multiple_entries: false) }

      it "ignores the quantity and creates a single entry" do
        expect {
          post "/api/v1/s/#{sweepstake.share_token}/register",
               params: { participant: { name: "Bob" }, quantity: 5 }
        }.to change(Participant, :count).by(1)
        expect(json["count"]).to eq(1)
      end
    end

    it "creates nothing when the name is blank" do
      sweepstake = create(:sweepstake, :with_entries, allow_multiple_entries: true)
      expect {
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "  " }, quantity: 3 }
      }.not_to change(Participant, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
