require "rails_helper"

RSpec.describe "Api::V1 swap allocations", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  # A drawn sweepstake where each of two players holds distinct teams.
  let(:sweepstake) { create(:sweepstake, :with_entries, entries_count: 4, user: user) }

  def draw!
    create(:participant, sweepstake: sweepstake, name: "Alice")
    create(:participant, sweepstake: sweepstake, name: "Bob")
    DrawRunner.new(sweepstake.reload, run_by: user).call
  end

  def team_owner(entry_public_id)
    sweepstake.current_draw.allocations
              .joins(:entry).find_by(entries: { public_id: entry_public_id })
              &.participant&.name
  end

  it "swaps the owners of two teams and flags the draw as adjusted" do
    draw!
    a, b = sweepstake.current_draw.allocations.includes(:entry).to_a
    entry_a = a.entry.public_id
    entry_b = b.entry.public_id
    owner_a_before = a.participant.name
    owner_b_before = b.participant.name
    # Pick two teams owned by different people (a 4-team / 2-player draw gives each two).
    expect(owner_a_before).not_to eq(owner_b_before)

    post "/api/v1/sweepstakes/#{sweepstake.public_id}/swap_allocations",
         params: { entry_ids: [entry_a, entry_b] }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(team_owner(entry_a)).to eq(owner_b_before)
    expect(team_owner(entry_b)).to eq(owner_a_before)
    expect(json.dig("sweepstake", "draw_adjusted")).to be(true)
    expect(sweepstake.current_draw.reload.adjusted_at).to be_present
  end

  it "keeps every team allocated exactly once after a swap" do
    draw!
    a, b = sweepstake.current_draw.allocations.includes(:entry).to_a
    post "/api/v1/sweepstakes/#{sweepstake.public_id}/swap_allocations",
         params: { entry_ids: [a.entry.public_id, b.entry.public_id] }, headers: headers
    expect(sweepstake.current_draw.allocations.count).to eq(4)
    expect(sweepstake.current_draw.allocations.pluck(:entry_id).uniq.size).to eq(4)
  end

  it "exposes adjusted_at in the public verification once swapped" do
    draw!
    a, b = sweepstake.current_draw.allocations.includes(:entry).to_a
    post "/api/v1/sweepstakes/#{sweepstake.public_id}/swap_allocations",
         params: { entry_ids: [a.entry.public_id, b.entry.public_id] }, headers: headers
    get "/api/v1/s/#{sweepstake.share_token}/verification"
    expect(json.dig("verification", "adjusted_at")).to be_present
  end

  it "rejects swapping two teams that belong to the same person" do
    draw!
    # Both of Alice's teams.
    alice = sweepstake.participants.find_by(name: "Alice")
    alice_entries = sweepstake.current_draw.allocations.where(participant: alice).includes(:entry).map { |a| a.entry.public_id }
    skip "draw left Alice with fewer than two teams" if alice_entries.size < 2

    post "/api/v1/sweepstakes/#{sweepstake.public_id}/swap_allocations",
         params: { entry_ids: alice_entries.first(2) }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("errors", 0, "code")).to eq("invalid_swap")
  end

  it "rejects when fewer than two distinct teams are given" do
    draw!
    entry = sweepstake.entries.first.public_id
    post "/api/v1/sweepstakes/#{sweepstake.public_id}/swap_allocations",
         params: { entry_ids: [entry, entry] }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "409s when the sweepstake has not been drawn" do
    post "/api/v1/sweepstakes/#{sweepstake.public_id}/swap_allocations",
         params: { entry_ids: %w[x y] }, headers: headers
    expect(response).to have_http_status(:conflict)
  end

  it "forbids a non-owner from swapping" do
    draw!
    other = create(:user)
    a, b = sweepstake.current_draw.allocations.includes(:entry).to_a
    post "/api/v1/sweepstakes/#{sweepstake.public_id}/swap_allocations",
         params: { entry_ids: [a.entry.public_id, b.entry.public_id] }, headers: auth_headers(other)
    expect(response).to have_http_status(:not_found).or have_http_status(:forbidden)
  end
end
