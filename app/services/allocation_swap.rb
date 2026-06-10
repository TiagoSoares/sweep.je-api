# Swaps the owners of two entries within a draw — for when two people agree to
# trade a team after the draw. The result no longer follows from the seed, so the
# draw is flagged as manually adjusted (the public verify panel says so).
class AllocationSwap
  class InvalidSwap < StandardError; end

  def initialize(draw, entry_a, entry_b)
    @draw = draw
    @entry_a = entry_a
    @entry_b = entry_b
  end

  def call
    raise InvalidSwap, "Pick two teams to swap" if @entry_a.nil? || @entry_b.nil?
    raise InvalidSwap, "Pick two different teams" if @entry_a.id == @entry_b.id

    alloc_a = @draw.allocations.find_by(entry_id: @entry_a.id)
    alloc_b = @draw.allocations.find_by(entry_id: @entry_b.id)
    raise InvalidSwap, "Those teams aren't part of this draw" unless alloc_a && alloc_b
    if alloc_a.participant_id == alloc_b.participant_id
      raise InvalidSwap, "Those teams already belong to the same person"
    end

    Draw.transaction do
      owner_a = alloc_a.participant
      owner_b = alloc_b.participant
      alloc_a.update!(participant_id: owner_b.id)
      alloc_b.update!(participant_id: owner_a.id)

      now = Time.current
      record = {
        "at" => now.utc.iso8601,
        "teams" => [@entry_a.name, @entry_b.name],
        "between" => [owner_a.name, owner_b.name]
      }
      @draw.update!(adjusted_at: now, adjustments: @draw.adjustments + [record])
    end
    @draw
  end
end
