class Entry < ApplicationRecord
  include HasPublicId

  belongs_to :sweepstake, inverse_of: :entries
  has_many :allocations, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :position, numericality: { only_integer: true }

  before_validation :assign_position, on: :create

  private

  # Append to the end of the sweepstake's entry list by default.
  def assign_position
    return if position.present? && !position.zero?

    self.position = (sweepstake&.entries&.maximum(:position) || 0) + 1
  end
end
