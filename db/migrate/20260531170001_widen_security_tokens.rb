class WidenSecurityTokens < ActiveRecord::Migration[8.1]
  # share_token and claim_token move from ULID (limit 26) to opaque high-entropy
  # tokens (SecureRandom.urlsafe_base64(24) -> 32 chars). Widen the columns.
  def up
    change_column :sweepstakes, :share_token, :string, limit: 64, null: false
    change_column :participants, :claim_token, :string, limit: 64, null: false
  end

  def down
    change_column :sweepstakes, :share_token, :string, limit: 26, null: false
    change_column :participants, :claim_token, :string, limit: 26, null: false
  end
end
