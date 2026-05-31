# Builds human-readable draw results and the verification payload from a
# sweepstake's current draw. Returns nil when the sweepstake hasn't been drawn.
module DrawResults
  module_function

  # Allocations grouped by participant, in registration order:
  # [{ participant:, participant_id:, entries: [names…] }, …]
  def results_for(sweepstake)
    draw = sweepstake.current_draw
    return nil unless draw

    allocations = draw.allocations.includes(:participant, :entry)
    allocations
      .group_by(&:participant)
      .sort_by { |p, _| [p.created_at, p.id] }
      .map do |participant, allocs|
        {
          participant: participant.name,
          participant_id: participant.public_id,
          entries: allocs.map(&:entry).sort_by(&:position).map(&:name)
        }
      end
  end

  # The entries assigned to one participant (for the /me view).
  def entries_for(participant)
    draw = participant.sweepstake.current_draw
    return nil unless draw

    participant.allocations
               .where(draw_id: draw.id)
               .includes(:entry)
               .map(&:entry)
               .sort_by(&:position)
               .map(&:name)
  end

  # Everything needed to independently reproduce and verify the draw (§4.4, §6.2):
  # the seed, algorithm version, and the canonical pre-shuffle orderings.
  def verification_for(sweepstake)
    draw = sweepstake.current_draw
    return nil unless draw

    {
      algorithm_version: draw.algorithm_version,
      seed: draw.seed,
      run_at: draw.run_at,
      trigger: draw.trigger,
      participant_order: ordered(draw.participant_order, sweepstake.participants),
      entry_order: ordered(draw.entry_order, sweepstake.entries),
      allocations: draw.allocations.includes(:participant, :entry).map do |a|
        { entry_id: a.entry.public_id, participant_id: a.participant.public_id }
      end
    }
  end

  # Map an ordered list of public_ids back to { id, name } using the given records.
  def ordered(public_ids, records)
    by_id = records.index_by(&:public_id)
    Array(public_ids).filter_map do |pid|
      rec = by_id[pid]
      { id: pid, name: rec&.name } if rec
    end
  end
end
