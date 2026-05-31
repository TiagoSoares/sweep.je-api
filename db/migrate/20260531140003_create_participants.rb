class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.string :public_id, null: false, limit: 26
      t.references :sweepstake, null: false, foreign_key: true
      t.string :name, null: false
      t.string :claim_token, null: false, limit: 26
      t.string :registered_ip
      t.string :user_agent

      t.timestamps
    end

    add_index :participants, :public_id, unique: true
    add_index :participants, :claim_token, unique: true
  end
end
