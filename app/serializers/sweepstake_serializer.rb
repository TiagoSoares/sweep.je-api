# Organizer-facing sweepstake view (dashboard + manage screens). Includes the
# share_token so the organizer can copy the share link.
class SweepstakeSerializer
  include Alba::Resource

  attributes :name, :description, :status, :allocation_rule,
             :max_participants, :participants_public, :timezone,
             :draw_at, :created_at, :prediction_fields

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

  # Draw results once drawn (nil otherwise), so the manage screen can show them.
  attribute :results do |s|
    DrawResults.results_for(s)
  end

  many :entries, resource: EntrySerializer
end
