class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :public_id, null: false, limit: 26
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.integer :role, null: false, default: 0
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :users, :public_id, unique: true
    add_index :users, :email, unique: true
  end
end
