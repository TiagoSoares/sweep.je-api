# Organizer-facing sweepstake view (dashboard + manage screens). Includes the
# share_token so the organizer can copy the share link.
class SweepstakeSerializer
  include Alba::Resource

  attributes :name, :description, :status, :allocation_rule,
             :max_participants, :participants_public, :allow_multiple_entries, :timezone,
             :draw_at, :created_at, :prediction_fields, :prizes

  attribute :id do |s|
    s.public_id
  end

  attribute :share_token do |s|
    s.share_token
  end

  attribute :registration_open do |s|
    s.registration_open?
  end

  attribute :entries_count do |s|
    s.entries.size
  end

  attribute :participants_count do |s|
    s.participants.size
  end

  # Total entries claimed across all participants, the cap (= team count), and
  # how many slots are left. entry_capacity/entries_remaining are nil when no
  # teams exist yet.
  attribute :entries_used do |s|
    s.entries_used
  end

  attribute :entry_capacity do |s|
    s.entry_capacity
  end

  attribute :entries_remaining do |s|
    s.remaining_entries
  end

  # Draw results once drawn (nil otherwise), so the manage screen can show them.
  attribute :results do |s|
    DrawResults.results_for(s)
  end

  many :entries, resource: EntrySerializer
end
