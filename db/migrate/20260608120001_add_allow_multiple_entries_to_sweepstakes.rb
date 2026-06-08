class AddAllowMultipleEntriesToSweepstakes < ActiveRecord::Migration[8.1]
  def change
    # When true, a person can register more than once on the share page (they
    # pick how many entries they want). Off by default: one entry per person.
    add_column :sweepstakes, :allow_multiple_entries, :boolean, default: false, null: false
  end
end
