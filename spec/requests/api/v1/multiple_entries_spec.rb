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

    it "exposes the flag and remaining entries on the public share page" do
      sweepstake = create(:sweepstake, :with_entries, entries_count: 8, allow_multiple_entries: true)
      get "/api/v1/s/#{sweepstake.share_token}"
      expect(json.dig("sweepstake", "allow_multiple_entries")).to be(true)
      expect(json.dig("sweepstake", "entries_remaining")).to eq(8)
    end
  end

  describe "registering with a quantity" do
    context "when multiple entries are allowed" do
      let(:sweepstake) { create(:sweepstake, :with_entries, entries_count: 12, allow_multiple_entries: true) }

      it "stores the count on a single participant row" do
        expect {
          post "/api/v1/s/#{sweepstake.share_token}/register",
               params: { participant: { name: "Bob" }, quantity: 3 }
        }.to change(Participant, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json["count"]).to eq(3)
        expect(json.dig("participant", "entries_count")).to eq(3)
        expect(sweepstake.participants.sole.entries_count).to eq(3)
      end

      it "clamps to the per-registration cap" do
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "Bob" }, quantity: 999 }
        expect(json["count"]).to eq(Sweepstake::MAX_ENTRIES_PER_REGISTRATION)
      end

      it "clamps to the free entry slots so totals never exceed the team count" do
        # 12 teams, 10 already taken -> only 2 slots left.
        create(:participant, sweepstake: sweepstake, entries_count: 10)
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "Bob" }, quantity: 9 }
        expect(json["count"]).to eq(2)
      end

      it "treats a missing/zero quantity as one entry" do
        post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "Bob" } }
        expect(json["count"]).to eq(1)
      end
    end

    context "when multiple entries are NOT allowed" do
      let(:sweepstake) { create(:sweepstake, :with_entries, allow_multiple_entries: false) }

      it "ignores the quantity and stores a single entry" do
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "Bob" }, quantity: 5 }
        expect(json["count"]).to eq(1)
        expect(json.dig("participant", "entries_count")).to eq(1)
      end
    end

    it "rejects a blank name without creating anything" do
      sweepstake = create(:sweepstake, :with_entries, allow_multiple_entries: true)
      expect {
        post "/api/v1/s/#{sweepstake.share_token}/register",
             params: { participant: { name: "  " }, quantity: 3 }
      }.not_to change(Participant, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "the entry cap (everyone gets at least one)" do
    it "closes registration once entries reach the team count" do
      sweepstake = create(:sweepstake, :with_entries, entries_count: 3)
      create(:participant, sweepstake: sweepstake, entries_count: 3) # all 3 slots taken

      post "/api/v1/s/#{sweepstake.share_token}/register", params: { participant: { name: "Late" } }
      expect(response).to have_http_status(:conflict)
      expect(json.dig("errors", 0, "code")).to eq("registration_closed")
    end

    it "guarantees every participant at least one team in the draw" do
      sweepstake = create(:sweepstake, :with_entries, entries_count: 6, allow_multiple_entries: true)
      # 6 teams: one person takes 4 entries, two take 1 each -> 6 total, fits exactly.
      create(:participant, sweepstake: sweepstake, name: "Whale", entries_count: 4)
      create(:participant, sweepstake: sweepstake, name: "Min1", entries_count: 1)
      create(:participant, sweepstake: sweepstake, name: "Min2", entries_count: 1)

      DrawRunner.new(sweepstake.reload, run_by: sweepstake.user).call
      get "/api/v1/s/#{sweepstake.share_token}/results"

      by_name = json["results"].to_h { |r| [r["participant"], r["entries"].size] }
      expect(by_name["Whale"]).to eq(4)
      expect(by_name["Min1"]).to eq(1)
      expect(by_name["Min2"]).to eq(1)
      expect(json["results"]).to all(satisfy { |r| r["entries"].size >= 1 })
    end
  end
end
