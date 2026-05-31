class Draw < ApplicationRecord
  include HasPublicId

  belongs_to :sweepstake
  belongs_to :run_by, class_name: "User", optional: true
  has_many :allocations, dependent: :destroy

  enum :trigger, { manual: 0, scheduled: 1 }, default: :manual

  validates :seed, :algorithm_version, :run_at, presence: true
end
