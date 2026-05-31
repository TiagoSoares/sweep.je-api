class CreateSweepstakes < ActiveRecord::Migration[8.1]
  def change
    create_table :sweepstakes do |t|
      t.string :public_id, null: false, limit: 26
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :share_token, null: false, limit: 26
      t.datetime :draw_at
      t.string :timezone, null: false, default: "UTC"
      t.integer :status, null: false, default: 1  # 0=draft 1=open 2=locked 3=drawn
      t.integer :allocation_rule, null: false, default: 0  # 0=auto_balance
      t.integer :max_participants
      t.boolean :participants_public, null: false, default: true

      t.timestamps
    end

    add_index :sweepstakes, :public_id, unique: true
    add_index :sweepstakes, :share_token, unique: true
  end
end
