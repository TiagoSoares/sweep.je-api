class AddPrizesToSweepstakes < ActiveRecord::Migration[8.1]
  def change
    # Ordered list of prize objects, each { "kind" => "position"|"prediction"|"custom",
    # "label" => "1st Place", "prize" => "£100" }. See Sweepstake for the shape.
    add_column :sweepstakes, :prizes, :json
  end
end
