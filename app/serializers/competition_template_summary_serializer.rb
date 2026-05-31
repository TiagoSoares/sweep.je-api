# Lightweight template view for lists (no entries payload).
class CompetitionTemplateSummarySerializer
  include Alba::Resource

  attributes :slug, :name, :category, :year, :status

  attribute :entries_count do |t|
    t.template_entries.size
  end
end
