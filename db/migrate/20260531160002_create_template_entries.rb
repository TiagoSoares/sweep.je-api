class CreateTemplateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :template_entries do |t|
      t.references :competition_template, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.json :metadata

      t.timestamps
    end

    add_index :template_entries, [:competition_template_id, :position]
  end
end
