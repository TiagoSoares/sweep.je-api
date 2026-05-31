class CreateCompetitionTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :competition_templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category
      t.integer :year
      t.integer :status, null: false, default: 0  # 0=draft 1=published 2=archived
      t.integer :version, null: false, default: 1

      t.timestamps
    end

    add_index :competition_templates, :slug, unique: true
  end
end
