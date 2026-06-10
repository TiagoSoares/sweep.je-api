class AddAdjustedAtToDraws < ActiveRecord::Migration[8.1]
  def change
    # Set when an organizer manually swaps allocations after the draw. The result
    # then no longer matches the seed, so the public verify panel says as much.
    add_column :draws, :adjusted_at, :datetime
  end
end
