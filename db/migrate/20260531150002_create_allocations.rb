class CreateAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :allocations do |t|
      t.references :draw, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true

      t.timestamps
    end

    # Every entry is assigned to exactly one participant within a draw.
    add_index :allocations, [:draw_id, :entry_id], unique: true
    add_index :allocations, [:draw_id, :participant_id]
  end
end
