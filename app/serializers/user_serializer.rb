class UserSerializer
  include Alba::Resource

  attributes :name, :email, :role, :created_at

  # Expose the public id as `id`; never leak the bigint primary key.
  attribute :id do |user|
    user.public_id
  end
end
