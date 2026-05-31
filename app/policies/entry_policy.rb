# Entries are managed by the owner of their parent sweepstake.
class EntryPolicy < ApplicationPolicy
  def update? = owner?
  def destroy? = owner?

  private

  def owner?
    user.present? && record.sweepstake.user_id == user.id
  end
end
