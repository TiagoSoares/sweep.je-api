# Public share-page view (§4.2). No secrets: no organizer email, no claim tokens,
# no entry list (entries are revealed via the draw in Phase 2). Participant names
# are shown only when the organizer made the list public.
class PublicSweepstakeSerializer
  include Alba::Resource

  attributes :name, :description, :status, :draw_at, :timezone, :prediction_fields, :prizes

  attribute :id do |s|
    s.public_id
  end

  attribute :host_name do |s|
    s.user.name
  end

  attribute :registration_open do |s|
    s.accepting_registrations?
  end

  attribute :entries_count do |s|
    s.entries.size
  end

  attribute :participants_count do |s|
    s.participants.size
  end

  attribute :participants_public do |s|
    s.participants_public
  end

  # Names (+ their prediction answers), only when the organizer opted to show them.
  attribute :participants do |s|
    next [] unless s.participants_public

    s.participants.map { |p| { name: p.name, registered_at: p.created_at, predictions: p.predictions } }
  end

  # Draw results once drawn (nil otherwise): each participant and their entries.
  attribute :results do |s|
    DrawResults.results_for(s)
  end
end
