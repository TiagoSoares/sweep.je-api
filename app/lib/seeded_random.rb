# Deterministic, seeded randomness for provably-recorded draws (§6.2, algorithm
# version 1). Given the same seed and inputs, this always produces the same
# result, so anyone can reproduce a draw from its published seed and verify it.
#
# The random stream is derived from SHA-256 of "<seed>:<label>:<counter>", which
# is trivial to re-implement in any language (see docs/DRAW_VERIFICATION.md).
#
# NOTE: integers are reduced modulo n. For sweepstake-sized n (tens of entries)
# against a 64-bit draw, modulo bias is negligible; this is documented, not hidden.
class SeededRandom
  # v2: odds-balanced pot draw (entries dealt in rank order, players shuffled
  # per pot). v1 was a flat shuffle-and-deal. The shuffle primitive is unchanged.
  ALGORITHM_VERSION = 2
  BITS = 64

  def initialize(seed)
    @seed = seed
  end

  # Uniform-ish integer in [0, n). `label` domain-separates independent streams
  # (e.g. "entry" vs "participant"); `counter` advances within a stream.
  def int(label, counter, n)
    raise ArgumentError, "n must be positive" unless n.positive?

    digest = Digest::SHA256.hexdigest("#{@seed}:#{label}:#{counter}")
    value = digest[0, BITS / 4].to_i(16) # first 64 bits
    value % n
  end

  # In-place Fisher–Yates shuffle of `array` using this seed and `label` stream.
  # Iterates i from last index down to 1, swapping with a derived index j in [0, i].
  def shuffle(array, label)
    arr = array.dup
    counter = 0
    (arr.length - 1).downto(1) do |i|
      j = int(label, counter, i + 1)
      counter += 1
      arr[i], arr[j] = arr[j], arr[i]
    end
    arr
  end

  def self.generate_seed
    SecureRandom.hex(32) # 256-bit
  end
end
