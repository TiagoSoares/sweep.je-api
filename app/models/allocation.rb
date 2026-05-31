class Allocation < ApplicationRecord
  belongs_to :draw
  belongs_to :participant
  belongs_to :entry
end
