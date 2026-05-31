require "rails_helper"

RSpec.describe DrawRunner do
  # Entries are created in `position` order, so "Team 1" is the top-ranked
  # (best odds) and the last team is the longest shot.
  def make(participants:, entries:)
    s = create(:sweepstake)
    entries.times { |i| create(:entry, sweepstake: s, position: i + 1, name: "Team #{i + 1}") }
    participants.times { |i| create(:participant, sweepstake: s, name: "P#{i + 1}") }
    s.reload
  end

  def counts_by_participant(draw)
    draw.allocations.group_by(&:participant_id).transform_values(&:size).values
  end

  it "assigns every entry exactly once and marks the sweepstake drawn" do
    s = make(participants: 4, entries: 12)
    draw = described_class.new(s).call

    expect(s.reload).to be_drawn
    expect(draw.allocations.count).to eq(12)
    expect(draw.allocations.map(&:entry_id).uniq.size).to eq(12) # no entry twice
  end

  it "balances evenly when entries divide by participants" do
    s = make(participants: 4, entries: 12)
    expect(counts_by_participant(described_class.new(s).call)).to all(eq(3))
  end

  it "spreads the favourites one-per-person (each player gets one of the top N)" do
    s = make(participants: 4, entries: 12)
    draw = described_class.new(s).call
    top_four = s.entries.order(:position).limit(4).map(&:id)
    holders = draw.allocations.select { |a| top_four.include?(a.entry_id) }.map(&:participant_id)
    expect(holders.uniq.size).to eq(4) # the four favourites went to four different people
  end

  it "spreads the remainder by at most one, using the lowest-ranked teams" do
    s = make(participants: 5, entries: 12) # pots of 5: ranks 1-5, 6-10, then 11-12 leftover
    draw = described_class.new(s).call
    counts = counts_by_participant(draw)
    expect(counts.sum).to eq(12)
    expect(counts).to contain_exactly(2, 2, 2, 3, 3)

    # The two "extra" teams are the lowest-ranked (positions 11 and 12).
    extras = draw.allocations
                 .group_by(&:participant_id)
                 .select { |_, allocs| allocs.size == 3 }
                 .flat_map { |_, allocs| allocs.map(&:entry) }
    lowest_two = s.entries.reorder(position: :desc).limit(2).map(&:name)
    expect(extras.map(&:name)).to include(*lowest_two)
  end

  it "leaves some participants with nothing when participants exceed entries" do
    s = make(participants: 5, entries: 3)
    draw = described_class.new(s).call
    assigned = draw.allocations.map(&:participant_id).uniq.size
    expect(assigned).to eq(3) # only 3 entries -> 3 players get one each, 2 get none
  end

  it "records the seed, algorithm version, and canonical orderings" do
    s = make(participants: 3, entries: 6)
    draw = described_class.new(s).call
    expect(draw.seed).to be_present
    expect(draw.algorithm_version).to eq(2)
    expect(draw.entry_order).to eq(s.entries.order(:position, :id).map(&:public_id))
    expect(draw.participant_order).to eq(s.participants.order(:created_at, :id).map(&:public_id))
  end

  it "is reproducible: replaying the recorded seed reproduces the allocation" do
    s = make(participants: 4, entries: 10)
    draw = described_class.new(s).call

    # Re-run the documented v2 algorithm from the recorded seed + orderings.
    rng = SeededRandom.new(draw.seed)
    entries = s.entries.order(:position, :id).to_a
    participants = s.participants.order(:created_at, :id).to_a
    expected = {}
    entries.each_slice(participants.length).with_index do |pot, pot_index|
      shuffled = rng.shuffle(participants, "pot:#{pot_index}")
      pot.each_with_index { |entry, j| expected[entry.public_id] = shuffled[j].public_id }
    end

    actual = draw.allocations.includes(:entry, :participant).to_h do |a|
      [a.entry.public_id, a.participant.public_id]
    end
    expect(actual).to eq(expected)
  end

  it "refuses to draw twice" do
    s = make(participants: 2, entries: 4)
    described_class.new(s).call
    expect { described_class.new(s.reload).call }.to raise_error(DrawRunner::NotDrawable)
  end

  it "refuses to draw with no participants or no entries" do
    expect { described_class.new(make(participants: 0, entries: 4)).call }
      .to raise_error(DrawRunner::NotDrawable)
    expect { described_class.new(make(participants: 3, entries: 0)).call }
      .to raise_error(DrawRunner::NotDrawable)
  end
end
