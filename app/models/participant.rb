class Participant < ApplicationRecord
  include HasPublicId
  include HasSecureTokenField

  secure_token_field :claim_token

  belongs_to :sweepstake, inverse_of: :participants
  has_many :allocations, dependent: :destroy

  # Duplicate names are intentionally allowed (§7); the UI warns on exact match.
  validates :name, presence: true, length: { maximum: 80 }
end
