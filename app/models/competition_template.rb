class CompetitionTemplate < ApplicationRecord
  has_many :template_entries, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :competition_template

  enum :status, { draft: 0, published: 1, archived: 2 }, default: :draft

  validates :name, presence: true, length: { maximum: 140 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 60 },
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase letters, numbers, and dashes" }
  validates :year, numericality: { only_integer: true, greater_than: 1900, less_than: 3000 }, allow_nil: true

  normalizes :prediction_fields, with: lambda { |fields|
    Array(fields).filter_map { |f| f.to_s.strip.presence }.uniq.first(Sweepstake::MAX_PREDICTION_FIELDS)
  }

  scope :published, -> { where(status: :published) }

  # Always an array, even when the column is NULL.
  def prediction_fields
    self[:prediction_fields] || []
  end

  # Build (unsaved) Entry records for a new sweepstake from this template's
  # entries. Decoupled copy — later template edits never affect existing draws (§5).
  def build_entries_for(sweepstake)
    template_entries.map do |te|
      sweepstake.entries.build(name: te.name, position: te.position, metadata: te.metadata)
    end
  end
end
