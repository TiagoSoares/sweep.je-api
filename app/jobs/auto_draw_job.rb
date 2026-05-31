# Runs a sweepstake's draw automatically at its scheduled `draw_at` (§4.3).
# Enqueued with `wait_until: draw_at` when a future draw date is set. Guards make
# it safe against duplicate enqueues and rescheduled dates:
#   - already drawn        -> no-op
#   - draw date moved later -> re-enqueue for the new time
#   - not yet due           -> re-enqueue (defensive)
#   - due & drawable        -> run the draw with trigger: scheduled
class AutoDrawJob < ApplicationJob
  queue_as :default

  def perform(sweepstake_id)
    sweepstake = Sweepstake.find_by(id: sweepstake_id)
    return unless sweepstake
    return if sweepstake.drawn?
    return if sweepstake.draw_at.blank?

    if sweepstake.draw_at > Time.current
      self.class.set(wait_until: sweepstake.draw_at).perform_later(sweepstake_id)
      return
    end

    DrawRunner.new(sweepstake, trigger: :scheduled).call
  rescue DrawRunner::NotDrawable
    # e.g. no participants/entries at draw time — leave it open for a manual draw.
    nil
  end
end
