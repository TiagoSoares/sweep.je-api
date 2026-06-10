class SweepstakePolicy < ApplicationPolicy
  def show? = owner?
  def update? = owner?
  def destroy? = owner?
  def lock? = owner?
  def draw? = owner?
  def reset_draw? = owner?
  def swap_allocations? = owner?
  def presentation? = owner?

  def create? = user.present?

  private

  def owner?
    user.present? && record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user&.id)
    end
  end
end
