# Assigns a ULID `public_id` to records before creation. ULIDs are sortable,
# URL-safe, and unguessable enough for non-secret public identifiers. Use this
# for anything exposed in URLs/JSON instead of leaking sequential bigint ids.
module HasPublicId
  extend ActiveSupport::Concern

  included do
    before_validation :assign_public_id, on: :create
    validates :public_id, presence: true, uniqueness: true
  end

  # Look records up by their public id (for controllers/params).
  module ClassMethods
    def find_by_public_id!(id)
      find_by!(public_id: id)
    end
  end

  private

  def assign_public_id
    self.public_id ||= ULID.generate
  end
end
