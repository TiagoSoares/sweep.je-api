# Base Pundit policy. Defaults deny; concrete policies opt actions in.
# `user` is the token-resolved current_user (may be nil for public actions).
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false

  def admin?
    user&.admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
