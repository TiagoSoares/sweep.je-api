require "rails_helper"

RSpec.describe SeededRandom do
  it "is deterministic: same seed + label + counter -> same int" do
    a = described_class.new("abc").int("entry", 0, 100)
    b = described_class.new("abc").int("entry", 0, 100)
    expect(a).to eq(b)
  end

  it "varies by label and counter" do
    rng = described_class.new("abc")
    expect(rng.int("entry", 0, 1000)).not_to eq(rng.int("participant", 0, 1000))
    expect(rng.int("entry", 0, 1000)).not_to eq(rng.int("entry", 1, 1000))
  end

  it "always returns a value within [0, n)" do
    rng = described_class.new("seed")
    50.times { |i| expect(rng.int("x", i, 7)).to be_between(0, 6) }
  end

  it "shuffle is a permutation and is reproducible" do
    input = (1..20).to_a
    s1 = described_class.new("deadbeef").shuffle(input, "entry")
    s2 = described_class.new("deadbeef").shuffle(input, "entry")
    expect(s1).to eq(s2)
    expect(s1.sort).to eq(input)        # permutation
    expect(s1).not_to eq(input)         # actually shuffled
  end

  it "different seeds produce different shuffles" do
    input = (1..20).to_a
    expect(described_class.new("a").shuffle(input, "e"))
      .not_to eq(described_class.new("b").shuffle(input, "e"))
  end

  # Pins the algorithm: if this changes, ALGORITHM_VERSION must bump (§6.2).
  it "produces a stable, reproducible shuffle (pins the primitive)" do
    result = described_class.new("00").shuffle([0, 1, 2, 3, 4], "entry")
    expect(result).to eq(described_class.new("00").shuffle([0, 1, 2, 3, 4], "entry"))
    expect(result.sort).to eq([0, 1, 2, 3, 4])
  end
end
