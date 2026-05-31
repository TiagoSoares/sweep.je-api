# Runs a sweepstake's draw: a seeded, odds-balanced "pot" allocation (§6.1, §6.2).
# Transactional and idempotent — a sweepstake can only be drawn once unless reset.
#
# Entries are ranked by their list order (position 1 = best odds / favourite).
# The draw deals them in rank order, one "pot" (a block the size of the
# participant count) at a time. Within each pot the participant order is shuffled
# from the seed, so every player gets exactly one team from each pot — the
# favourites spread one-per-person, the long-shots shared out. When the teams
# don't divide evenly, the final partial pot (the lowest-ranked leftovers) lands
# on a random subset of players.
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
    entries = @sweepstake.entries.order(:position, :id).to_a # rank order (best first)
    seed = SeededRandom.generate_seed
    rng = SeededRandom.new(seed)

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

      Allocation.insert_all!(allocate(draw, entries, participants, rng))
      @sweepstake.update!(status: :drawn)
      draw
    end
  end

  private

  # Deal entries pot-by-pot in rank order; shuffle players within each pot.
  def allocate(draw, entries, participants, rng)
    now = Time.current
    rows = []
    entries.each_slice(participants.length).with_index do |pot, pot_index|
      shuffled = rng.shuffle(participants, "pot:#{pot_index}")
      pot.each_with_index do |entry, j|
        rows << { draw_id: draw.id, participant_id: shuffled[j].id, entry_id: entry.id,
                  created_at: now, updated_at: now }
      end
    end
    rows
  end

  def guard!
    raise NotDrawable, "This sweepstake has already been drawn" if @sweepstake.drawn?
    raise NotDrawable, "Add at least one entry before drawing" if @sweepstake.entries.empty?
    raise NotDrawable, "No one has registered yet" if @sweepstake.participants.empty?
  end
end
