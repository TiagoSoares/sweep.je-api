require "rails_helper"

RSpec.describe DrawRunner do
  def make(participants:, entries:)
    s = create(:sweepstake)
    entries.times { |i| create(:entry, sweepstake: s, position: i + 1, name: "Team #{i + 1}") }
    participants.times { |i| create(:participant, sweepstake: s, name: "P#{i + 1}") }
    s.reload
  end

  it "assigns every entry exactly once and marks the sweepstake drawn" do
    s = make(participants: 4, entries: 12)
    draw = described_class.new(s).call

    expect(s.reload).to be_drawn
    expect(draw.allocations.count).to eq(12)
    expect(draw.allocations.map(&:entry_id).uniq.size).to eq(12) # no entry twice
  end

  it "auto-balances evenly when entries divide by participants" do
    s = make(participants: 4, entries: 12)
    draw = described_class.new(s).call
    counts = draw.allocations.group_by(&:participant_id).transform_values(&:size)
    expect(counts.values).to all(eq(3))
  end

  it "spreads the remainder by at most one when uneven" do
    s = make(participants: 5, entries: 12) # 12 / 5 -> 2 or 3 each
    draw = described_class.new(s).call
    counts = draw.allocations.group_by(&:participant_id).transform_values(&:size).values
    expect(counts.sum).to eq(12)
    expect(counts.max - counts.min).to be <= 1
    expect(counts).to contain_exactly(2, 2, 2, 3, 3)
  end

  it "leaves some participants with nothing when participants exceed entries" do
    s = make(participants: 5, entries: 3)
    draw = described_class.new(s).call
    assigned = draw.allocations.map(&:participant_id).uniq.size
    expect(assigned).to eq(3) # only 3 entries -> 3 participants get one each
  end

  it "records the seed and canonical orderings for verification" do
    s = make(participants: 3, entries: 6)
    draw = described_class.new(s).call
    expect(draw.seed).to be_present
    expect(draw.algorithm_version).to eq(1)
    expect(draw.entry_order).to eq(s.entries.order(:position, :id).map(&:public_id))
    expect(draw.participant_order).to eq(s.participants.order(:created_at, :id).map(&:public_id))
  end

  it "is reproducible: replaying the recorded seed reproduces the allocation" do
    s = make(participants: 4, entries: 10)
    draw = described_class.new(s).call

    # Re-run the documented algorithm from the recorded seed + orderings.
    rng = SeededRandom.new(draw.seed)
    entries = s.entries.order(:position, :id).to_a
    participants = s.participants.order(:created_at, :id).to_a
    shuffled_entries = rng.shuffle(entries, "entry")
    shuffled_participants = rng.shuffle(participants, "participant")
    expected = shuffled_entries.each_with_index.to_h do |entry, i|
      [entry.public_id, shuffled_participants[i % shuffled_participants.length].public_id]
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
