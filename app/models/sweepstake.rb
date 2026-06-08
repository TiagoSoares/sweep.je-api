class Sweepstake < ApplicationRecord
  include HasPublicId
  include HasSecureTokenField

  # Upper bound on entries per sweepstake — guards against oversized payloads.
  MAX_ENTRIES = 500
  # Most entries one person can claim in a single registration (when the
  # organizer allows multiple entries). Caps the share-page quantity dropdown.
  MAX_ENTRIES_PER_REGISTRATION = 10
  # Free-text prediction questions (e.g. Golden Ball/Boot/Glove).
  MAX_PREDICTION_FIELDS = 12
  PREDICTION_LABEL_MAX = 60

  # Prizes (e.g. 1st/2nd/3rd place, a prize per prediction question, or custom
  # extras like a wooden spoon). Stored as an ordered list of objects.
  MAX_PRIZES = 50
  PRIZE_LABEL_MAX = 80
  PRIZE_VALUE_MAX = 200
  PRIZE_KINDS = %w[position prediction custom].freeze

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

  # Normalize prizes to a clean list of { "kind", "label", "prize" } hashes.
  # Each entry needs a non-blank prize value (an empty position row is dropped);
  # labels/values are trimmed, kinds are coerced to a known kind, and the list is
  # capped. Order is preserved (it's the display order).
  normalizes :prizes, with: ->(prizes) { Sweepstake.normalize_prizes(prizes) }

  def self.normalize_prizes(prizes)
    Array(prizes).filter_map do |raw|
      attrs = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
      next unless attrs.is_a?(Hash)

      attrs = attrs.symbolize_keys
      prize = attrs[:prize].to_s.strip
      next if prize.blank?

      kind = attrs[:kind].to_s
      kind = "custom" unless PRIZE_KINDS.include?(kind)
      { "kind" => kind, "label" => attrs[:label].to_s.strip, "prize" => prize }
    end.first(MAX_PRIZES)
  end

  validates :name, presence: true, length: { maximum: 140 }
  validates :description, length: { maximum: 2000 }, allow_nil: true
  validates :timezone, presence: true, length: { maximum: 60 }
  validates :max_participants, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100_000 }, allow_nil: true
  validate :timezone_must_be_valid
  validate :prediction_fields_within_limits
  validate :prizes_within_limits

  # Always an array, even when the column is NULL.
  def prediction_fields
    self[:prediction_fields] || []
  end

  # Always an array, even when the column is NULL.
  def prizes
    self[:prizes] || []
  end

  # Registration is accepted only while open and below any participant cap.
  def registration_open?
    open?
  end

  # Full when either the organizer's people cap is reached or there are no free
  # entry slots left (total entries can't exceed the number of teams, so everyone
  # is guaranteed at least one in the draw).
  def full?
    people_capped = max_participants.present? && participants.count >= max_participants
    people_capped || remaining_entries == 0
  end

  # Max total entries across all participants: one per team, so every entry can be
  # dealt a team and no one is left empty-handed. nil when no teams exist yet.
  def entry_capacity
    count = entries.size
    count.positive? ? count : nil
  end

  # Entries already claimed across all participants.
  def entries_used
    participants.sum(:entries_count)
  end

  # Free entry slots remaining before hitting the team count; nil when uncapped
  # (no teams set yet).
  def remaining_entries
    cap = entry_capacity
    return nil unless cap

    [cap - entries_used, 0].max
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

  def prizes_within_limits
    if prizes.size > MAX_PRIZES
      errors.add(:prizes, "can have at most #{MAX_PRIZES} prizes")
    end
    if prizes.any? { |p| p["label"].to_s.length > PRIZE_LABEL_MAX }
      errors.add(:prizes, "labels must be #{PRIZE_LABEL_MAX} characters or fewer")
    end
    if prizes.any? { |p| p["prize"].to_s.length > PRIZE_VALUE_MAX }
      errors.add(:prizes, "must be #{PRIZE_VALUE_MAX} characters or fewer")
    end
  end
end
