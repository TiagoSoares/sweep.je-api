require "rails_helper"

RSpec.describe "Api::V1 prizes", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "defining prizes on create" do
    it "stores the prizes passed in, preserving order" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "WC", prizes: [
             { kind: "position", label: "1st Place", prize: "£100" },
             { kind: "position", label: "2nd Place", prize: "£50" },
             { kind: "prediction", label: "Golden Boot", prize: "Bottle of champagne" },
             { kind: "custom", label: "Wooden spoon", prize: "An actual wooden spoon" }
           ] } },
           headers: headers
      expect(response).to have_http_status(:created)
      expect(json.dig("sweepstake", "prizes")).to eq([
        { "kind" => "position", "label" => "1st Place", "prize" => "£100" },
        { "kind" => "position", "label" => "2nd Place", "prize" => "£50" },
        { "kind" => "prediction", "label" => "Golden Boot", "prize" => "Bottle of champagne" },
        { "kind" => "custom", "label" => "Wooden spoon", "prize" => "An actual wooden spoon" }
      ])
    end

    it "trims labels/values, drops rows with a blank prize, and coerces unknown kinds to custom" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "WC", prizes: [
             { kind: "position", label: " 1st Place ", prize: " £100 " },
             { kind: "position", label: "2nd Place", prize: "  " },
             { kind: "hacker", label: "Mystery", prize: "?" }
           ] } },
           headers: headers
      expect(json.dig("sweepstake", "prizes")).to eq([
        { "kind" => "position", "label" => "1st Place", "prize" => "£100" },
        { "kind" => "custom", "label" => "Mystery", "prize" => "?" }
      ])
    end

    it "defaults to an empty list when none are given" do
      post "/api/v1/sweepstakes", params: { sweepstake: { name: "WC" } }, headers: headers
      expect(json.dig("sweepstake", "prizes")).to eq([])
    end
  end

  describe "editing prizes" do
    let(:sweepstake) { create(:sweepstake, user: user) }

    it "replaces the prize list on update" do
      patch "/api/v1/sweepstakes/#{sweepstake.public_id}",
            params: { sweepstake: { prizes: [{ kind: "position", label: "Winner", prize: "Trophy" }] } },
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(json.dig("sweepstake", "prizes")).to eq([
        { "kind" => "position", "label" => "Winner", "prize" => "Trophy" }
      ])
    end
  end

  describe "prizes on the public share page" do
    let(:sweepstake) do
      create(:sweepstake, :with_entries,
             prizes: [{ "kind" => "position", "label" => "1st Place", "prize" => "£100" }])
    end

    it "exposes the prizes to the public" do
      get "/api/v1/s/#{sweepstake.share_token}"
      expect(json.dig("sweepstake", "prizes")).to eq([
        { "kind" => "position", "label" => "1st Place", "prize" => "£100" }
      ])
    end
  end

  describe "validation" do
    it "rejects a prize value over the length cap" do
      post "/api/v1/sweepstakes",
           params: { sweepstake: { name: "WC", prizes: [
             { kind: "custom", label: "X", prize: "a" * (Sweepstake::PRIZE_VALUE_MAX + 1) }
           ] } },
           headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
