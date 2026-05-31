# Participants are managed (e.g. removed) by the owner of their sweepstake.
class ParticipantPolicy < ApplicationPolicy
  def destroy? = owner?

  private

  def owner?
    user.present? && record.sweepstake.user_id == user.id
  end
end
