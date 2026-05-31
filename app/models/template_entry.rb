class TemplateEntry < ApplicationRecord
  belongs_to :competition_template, inverse_of: :template_entries

  validates :name, presence: true, length: { maximum: 100 }
end
