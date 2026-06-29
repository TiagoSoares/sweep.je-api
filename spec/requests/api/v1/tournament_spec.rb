require "rails_helper"

RSpec.describe "Api::V1 tournament", type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:standings) do
    {
      "competition" => { "code" => "WC", "name" => "FIFA World Cup" },
      "season" => { "startDate" => "2026-06-11" },
      "standings" => [
        {
          "stage" => "GROUP_STAGE", "type" => "TOTAL", "group" => "GROUP_A",
          "table" => [
            { "position" => 1, "team" => { "id" => 1, "name" => "France", "tla" => "FRA" },
              "playedGames" => 3, "won" => 3, "draw" => 0, "lost" => 0,
              "points" => 9, "goalsFor" => 6, "goalsAgainst" => 1, "goalDifference" => 5 }
          ]
        }
      ]
    }
  end
  let(:matches) { { "matches" => [] } }

  context "a World Cup sweepstake" do
    let(:template) { create(:competition_template, slug: "world-cup-2026") }
    let(:sweepstake) { create(:sweepstake, competition_template: template) }

    before do
      create(:entry, sweepstake:, name: "France", metadata: { "country_code" => "FRA" })
    end

    it "returns the tournament payload" do
      allow_any_instance_of(FootballData::Client).to receive(:standings).and_return(standings)
      allow_any_instance_of(FootballData::Client).to receive(:matches).and_return(matches)

      get "/api/v1/s/#{sweepstake.share_token}/tournament"

      expect(response).to have_http_status(:ok)
      expect(json.dig("competition", "code")).to eq("WC")
      expect(json["groups"].first["name"]).to eq("Group A")
      expect(json["entries"]).to include("entry_id" => sweepstake.entries.first.public_id, "team_id" => 1, "status" => "alive")
      expect(json["last_updated"]).to be_present
    end

    it "503s with a clear code when upstream is unavailable" do
      allow_any_instance_of(FootballData::Client).to receive(:standings)
        .and_raise(FootballData::Unavailable, "down")

      get "/api/v1/s/#{sweepstake.share_token}/tournament"

      expect(response).to have_http_status(:service_unavailable)
      expect(json.dig("errors", 0, "code")).to eq("tournament_unavailable")
    end

    it "503s when the API token isn't configured" do
      allow_any_instance_of(FootballData::Client).to receive(:standings)
        .and_raise(FootballData::NotConfigured, "no token")

      get "/api/v1/s/#{sweepstake.share_token}/tournament"
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  it "404s for a non-World-Cup sweepstake" do
    sweepstake = create(:sweepstake) # no WC template
    get "/api/v1/s/#{sweepstake.share_token}/tournament"
    expect(response).to have_http_status(:not_found)
  end

  it "404s for an unknown share token" do
    get "/api/v1/s/nope/tournament"
    expect(response).to have_http_status(:not_found)
  end
end
