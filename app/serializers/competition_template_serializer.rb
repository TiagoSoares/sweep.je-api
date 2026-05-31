# Full template view (with its entries) for the show endpoint and admin.
class CompetitionTemplateSerializer
  include Alba::Resource

  attributes :slug, :name, :category, :year, :status, :version

  attribute :entries_count do |t|
    t.template_entries.size
  end

  attribute :entries do |t|
    t.template_entries.map { |e| { name: e.name, position: e.position, metadata: e.metadata } }
  end
end
