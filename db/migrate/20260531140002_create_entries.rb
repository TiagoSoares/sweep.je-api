class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.string :public_id, null: false, limit: 26
      t.references :sweepstake, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.json :metadata

      t.timestamps
    end

    add_index :entries, :public_id, unique: true
    add_index :entries, [:sweepstake_id, :position]
  end
end
