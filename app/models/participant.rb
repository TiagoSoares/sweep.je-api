class Participant < ApplicationRecord
  include HasPublicId
  include HasSecureTokenField

  ANSWER_MAX = 100

  secure_token_field :claim_token

  belongs_to :sweepstake, inverse_of: :participants
  has_many :allocations, dependent: :destroy

  # Duplicate names are intentionally allowed (§7); the UI warns on exact match.
  validates :name, presence: true, length: { maximum: 80 }

  # Restrict answers to the sweepstake's known questions just before saving, so it
  # works regardless of attribute assignment order.
  before_validation :restrict_predictions_to_known_questions

  # Always a hash, even when the column is NULL.
  def predictions
    self[:predictions] || {}
  end

  # Accept a { label => guess } map; trim and truncate each answer, drop blanks.
  def predictions=(answers)
    cleaned = Array(answers&.to_h).to_h.filter_map do |label, value|
      v = value.to_s.strip
      [label.to_s, v.first(ANSWER_MAX)] if v.present?
    end
    super(cleaned.to_h)
  end

  private

  def restrict_predictions_to_known_questions
    allowed = sweepstake&.prediction_fields || []
    self.predictions = predictions.slice(*allowed)
  end
end
