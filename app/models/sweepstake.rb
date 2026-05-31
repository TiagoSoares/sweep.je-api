class Sweepstake < ApplicationRecord
  include HasPublicId
  include HasSecureTokenField

  # Upper bound on entries per sweepstake — guards against oversized payloads.
  MAX_ENTRIES = 500
  # Free-text prediction questions (e.g. Golden Ball/Boot/Glove).
  MAX_PREDICTION_FIELDS = 12
  PREDICTION_LABEL_MAX = 60

  secure_token_field :share_token

  belongs_to :user
  belongs_to :competition_template, optional: true
  has_many :entries, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :sweepstake
  has_many :participants, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :sweepstake
  has_many :draws, -> { order(created_at: :desc) }, dependent: :destroy, inverse_of: :sweepstake

  # The most recent draw (the current result; older draws are kept as history).
  def current_draw
    draws.first
  end

  # Enqueue the scheduled auto-draw when a future draw date is set (§4.3). Safe to
  # call repeatedly — the job guards against double-draws and reschedules.
  def schedule_auto_draw!
    return unless open? && draw_at.present? && draw_at.future?

    AutoDrawJob.set(wait_until: draw_at).perform_later(id)
  end

  # Lifecycle (§4.3): created -> open (accepting registrations) -> locked
  # (registration closed, pre-draw) -> drawn. `draft` is reserved for future use
  # (e.g. unshared sweepstakes); new records default to :open so the share link
  # works immediately.
  enum :status, { draft: 0, open: 1, locked: 2, drawn: 3 }, default: :open

  # Allocation strategy for the draw (§6.1). Only auto_balance in v1; the column
  # exists so future rules (one_per_person, etc.) need no migration.
  enum :allocation_rule, { auto_balance: 0 }, default: :auto_balance

  # Normalize prediction fields to a clean, de-duplicated, capped list of labels.
  normalizes :prediction_fields, with: lambda { |fields|
    Array(fields).filter_map { |f| f.to_s.strip.presence }.uniq.first(MAX_PREDICTION_FIELDS)
  }

  validates :name, presence: true, length: { maximum: 140 }
  validates :description, length: { maximum: 2000 }, allow_nil: true
  validates :timezone, presence: true, length: { maximum: 60 }
  validates :max_participants, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100_000 }, allow_nil: true
  validate :timezone_must_be_valid
  validate :prediction_fields_within_limits

  # Always an array, even when the column is NULL.
  def prediction_fields
    self[:prediction_fields] || []
  end

  # Registration is accepted only while open and below any participant cap.
  def registration_open?
    open?
  end

  def full?
    max_participants.present? && participants.count >= max_participants
  end

  def accepting_registrations?
    registration_open? && !full?
  end

  private

  # Validate against the full IANA tz database so we accept any real browser
  # time zone (e.g. "Europe/London") but reject junk input.
  def timezone_must_be_valid
    return if timezone.blank?

    TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, "is not a valid time zone")
  end

  def prediction_fields_within_limits
    if prediction_fields.size > MAX_PREDICTION_FIELDS
      errors.add(:prediction_fields, "can have at most #{MAX_PREDICTION_FIELDS} questions")
    end
    if prediction_fields.any? { |f| f.length > PREDICTION_LABEL_MAX }
      errors.add(:prediction_fields, "labels must be #{PREDICTION_LABEL_MAX} characters or fewer")
    end
  end
end
