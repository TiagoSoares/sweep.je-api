class CreateDraws < ActiveRecord::Migration[8.1]
  def change
    create_table :draws do |t|
      t.string :public_id, null: false, limit: 26
      t.references :sweepstake, null: false, foreign_key: true
      t.string :seed, null: false
      t.integer :algorithm_version, null: false, default: 1
      t.json :participant_order, null: false   # ordered array of participant public_ids
      t.json :entry_order, null: false          # ordered array of entry public_ids
      t.datetime :run_at, null: false
      t.references :run_by, foreign_key: { to_table: :users } # null for scheduled draws
      t.integer :trigger, null: false, default: 0  # 0=manual 1=scheduled

      # Reserved for a future commit-reveal + public-entropy fairness mode (§6.2).
      t.string :seed_commitment
      t.string :public_entropy_source
      t.string :public_entropy_value

      t.timestamps
    end

    add_index :draws, :public_id, unique: true
  end
end
