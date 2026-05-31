# Runs a sweepstake's draw: auto-balance allocation over an auditable seeded
# shuffle (§6.1, §6.2). Transactional and idempotent — a sweepstake can only be
# drawn once unless explicitly reset.
class DrawRunner
  # Raised when a draw can't run (already drawn, no participants, no entries).
  class NotDrawable < StandardError; end

  def initialize(sweepstake, run_by: nil, trigger: :manual)
    @sweepstake = sweepstake
    @run_by = run_by
    @trigger = trigger
  end

  def call
    guard!

    participants = @sweepstake.participants.order(:created_at, :id).to_a
    entries = @sweepstake.entries.order(:position, :id).to_a
    seed = SeededRandom.generate_seed
    rng = SeededRandom.new(seed)

    # Shuffle both decks from independent seed streams; deal entries round-robin
    # to participants. Because participant order is shuffled, the few "extra"
    # entries (when entries don't divide evenly) land on random participants.
    shuffled_entries = rng.shuffle(entries, "entry")
    shuffled_participants = rng.shuffle(participants, "participant")

    Sweepstake.transaction do
      draw = @sweepstake.draws.create!(
        seed:,
        algorithm_version: SeededRandom::ALGORITHM_VERSION,
        participant_order: participants.map(&:public_id),
        entry_order: entries.map(&:public_id),
        run_at: Time.current,
        run_by: @run_by,
        trigger: @trigger
      )

      rows = shuffled_entries.each_with_index.map do |entry, i|
        participant = shuffled_participants[i % shuffled_participants.length]
        { draw_id: draw.id, participant_id: participant.id, entry_id: entry.id,
          created_at: Time.current, updated_at: Time.current }
      end
      Allocation.insert_all!(rows)

      @sweepstake.update!(status: :drawn)
      draw
    end
  end

  private

  def guard!
    raise NotDrawable, "This sweepstake has already been drawn" if @sweepstake.drawn?
    raise NotDrawable, "Add at least one entry before drawing" if @sweepstake.entries.empty?
    raise NotDrawable, "No one has registered yet" if @sweepstake.participants.empty?
  end
end
