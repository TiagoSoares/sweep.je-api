# Organizer-facing participant view (manage screen). Exposes the public_id so the
# organizer can remove a registrant; never exposes the private claim_token.
class ParticipantSerializer
  include Alba::Resource

  attributes :name, :created_at

  attribute :id do |participant|
    participant.public_id
  end
end
