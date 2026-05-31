class AddTemplateToSweepstakes < ActiveRecord::Migration[8.1]
  def change
    # Provenance only: which template (if any) a sweepstake's entries came from.
    # Entries are copied on creation, so this is nullable and not a hard dependency.
    add_reference :sweepstakes, :competition_template, null: true, foreign_key: true
  end
end
