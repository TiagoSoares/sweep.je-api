class EntrySerializer
  include Alba::Resource

  attributes :name, :position, :metadata

  attribute :id do |entry|
    entry.public_id
  end
end
