class AddPredictions < ActiveRecord::Migration[8.1]
  def change
    # Ordered list of free-text prediction question labels, e.g.
    # ["Golden Ball", "Golden Boot", "Golden Glove"].
    add_column :sweepstakes, :prediction_fields, :json
    add_column :competition_templates, :prediction_fields, :json

    # Each participant's answers as a { label => guess } map.
    add_column :participants, :predictions, :json
  end
end
