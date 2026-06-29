require "rails_helper"

RSpec.describe WorldCup::Tournament do
  # --- fixture helpers (mirror football-data.org v4 shapes) ----------------
  def team(id, name, tla)
    { "id" => id, "name" => name, "tla" => tla }
  end

  def standing_row(pos, id, name, tla, won:, lost:, draw: 0, gf: 0, ga: 0)
    {
      "position" => pos, "team" => team(id, name, tla),
      "playedGames" => won + lost + draw, "won" => won, "draw" => draw, "lost" => lost,
      "points" => won * 3 + draw, "goalsFor" => gf, "goalsAgainst" => ga, "goalDifference" => gf - ga
    }
  end

  let(:standings) do
    {
      "competition" => { "code" => "WC", "name" => "FIFA World Cup" },
      "season" => { "startDate" => "2026-06-11" },
      "standings" => [
        {
          "stage" => "GROUP_STAGE", "type" => "TOTAL", "group" => "GROUP_A",
          "table" => [
            standing_row(1, 1, "France", "FRA", won: 3, lost: 0, gf: 6, ga: 1),
            standing_row(2, 2, "Brazil", "BRA", won: 2, lost: 1, gf: 4, ga: 2),
            standing_row(3, 3, "Japan", "JPN", won: 1, lost: 2, gf: 2, ga: 4),
            standing_row(4, 4, "Qatar", "QAT", won: 0, lost: 3, gf: 1, ga: 6)
          ]
        }
      ]
    }
  end

  def group_match(home_id, home, away_id, away, status: "FINISHED")
    {
      "id" => rand(1000), "stage" => "GROUP_STAGE", "group" => "GROUP_A", "status" => status,
      "utcDate" => "2026-06-12T18:00:00Z",
      "homeTeam" => team(home_id, home, nil), "awayTeam" => team(away_id, away, nil),
      "score" => { "winner" => "HOME_TEAM", "fullTime" => { "home" => 1, "away" => 0 } }
    }
  end

  # All group matches finished -> group is decided.
  let(:group_matches) do
    [group_match(1, "France", 4, "Qatar"), group_match(2, "Brazil", 3, "Japan"),
     group_match(1, "France", 2, "Brazil"), group_match(3, "Japan", 4, "Qatar")]
  end

  let(:client) { instance_double(FootballData::Client) }

  let(:template) { create(:competition_template, slug: "world-cup-2026") }
  let(:sweepstake) { create(:sweepstake, competition_template: template) }

  before do
    %w[France Brazil Qatar].each_with_index do |name, i|
      create(:entry, sweepstake:, name:, position: i + 1,
                     metadata: { "country_code" => { "France" => "FRA", "Brazil" => "BRA", "Qatar" => "QAT" }[name] })
    end
    allow(client).to receive(:standings).and_return(standings)
    allow(client).to receive(:matches).and_return("matches" => matches)
  end

  subject(:payload) { described_class.new(sweepstake, client:).call }

  context "during the group stage (group complete, no knockout yet)" do
    let(:matches) { group_matches }

    it "builds the competition + group standings" do
      expect(payload[:competition]).to eq(code: "WC", name: "FIFA World Cup", season: "2026")
      group = payload[:groups].first
      expect(group[:name]).to eq("Group A")
      expect(group[:standings].map { |r| r[:team][:name] }).to eq(%w[France Brazil Japan Qatar])
      expect(group[:standings].first[:team][:flag]).to eq("🇫🇷")
      expect(group[:standings].first).to include(position: 1, points: 9, won: 3, status: "advanced")
    end

    it "marks the top two advanced and the rest eliminated" do
      statuses = payload[:teams].to_h { |t| [t[:name], t[:status]] }
      expect(statuses).to eq("France" => "alive", "Brazil" => "alive", "Japan" => "eliminated", "Qatar" => "eliminated")
    end

    it "maps entries to teams by country_code and carries their status" do
      entries = payload[:entries].to_h { |e| [e[:team_id], e[:status]] }
      expect(entries).to eq(1 => "alive", 2 => "alive", 4 => "eliminated")
      expect(payload[:entries].map { |e| e[:entry_id] }).to all(be_present)
    end

    it "has an empty knockout and reports the group stage" do
      expect(payload[:knockout]).to be_empty
      expect(payload[:current_stage]).to eq("FINISHED").or eq("GROUP_STAGE")
    end
  end

  context "once the knockout is under way" do
    # France beat Brazil in the last 16; Japan/Qatar didn't qualify.
    let(:knockout) do
      {
        "id" => 999, "stage" => "LAST_16", "status" => "FINISHED", "utcDate" => "2026-07-01T18:00:00Z",
        "homeTeam" => team(1, "France", "FRA"), "awayTeam" => team(2, "Brazil", "BRA"),
        "score" => { "winner" => "HOME_TEAM", "fullTime" => { "home" => 2, "away" => 1 } }
      }
    end
    let(:matches) { group_matches + [knockout] }

    it "eliminates the knockout loser and keeps the winner alive" do
      statuses = payload[:teams].to_h { |t| [t[:name], t[:status]] }
      expect(statuses["France"]).to eq("alive")
      expect(statuses["Brazil"]).to eq("eliminated")
    end

    it "eliminates group teams that didn't reach the knockout" do
      statuses = payload[:teams].to_h { |t| [t[:name], t[:status]] }
      expect(statuses["Japan"]).to eq("eliminated")
      expect(statuses["Qatar"]).to eq("eliminated")
    end

    it "reflects the knockout result in the entries" do
      entries = payload[:entries].to_h { |e| [e[:team_id], e[:status]] }
      expect(entries).to eq(1 => "alive", 2 => "eliminated", 4 => "eliminated")
    end

    it "exposes the knockout bracket with the winner" do
      round = payload[:knockout].find { |r| r[:stage] == "LAST_16" }
      match = round[:matches].first
      expect(match).to include(home_score: 2, away_score: 1, winner: "HOME", status: "FINISHED")
      expect(match[:home][:name]).to eq("France")
    end
  end

  context "entry matching" do
    let(:matches) { group_matches }

    it "matches by fd_team_id when present, and by name as a fallback" do
      sweepstake.entries.destroy_all
      create(:entry, sweepstake:, name: "Les Bleus", metadata: { "fd_team_id" => 1 }) # id wins over name
      create(:entry, sweepstake:, name: "Japan", metadata: {}) # name fallback
      entries = described_class.new(sweepstake, client:).call[:entries].to_h { |e| [e[:team_id], e[:status]] }
      expect(entries).to eq(1 => "alive", 3 => "eliminated")
    end

    it "skips (and logs) entries with no matching team" do
      create(:entry, sweepstake:, name: "Atlantis", metadata: {})
      expect(Rails.logger).to receive(:warn).with(/no football-data team/).at_least(:once)
      ids = described_class.new(sweepstake, client:).call[:entries].map { |e| e[:team_id] }
      expect(ids).not_to include(nil)
    end
  end
end
