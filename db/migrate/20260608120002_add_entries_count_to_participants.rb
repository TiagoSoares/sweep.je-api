class AddEntriesCountToParticipants < ActiveRecord::Migration[8.1]
  def change
    # How many entries this person holds. Each entry is one slot in the draw, so a
    # participant with entries_count = 6 is dealt teams as if they were six players.
    add_column :participants, :entries_count, :integer, default: 1, null: false
  end
end
