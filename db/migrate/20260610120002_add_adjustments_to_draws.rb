class AddAdjustmentsToDraws < ActiveRecord::Migration[8.1]
  def change
    # Log of manual post-draw swaps, each:
    # { "at" => iso8601, "teams" => [name, name], "between" => [name, name] }.
    add_column :draws, :adjustments, :json
  end
end
