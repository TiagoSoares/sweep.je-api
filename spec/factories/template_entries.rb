FactoryBot.define do
  factory :template_entry do
    association :competition_template
    sequence(:name) { |n| "Team #{n}" }
    position { 1 }
  end
end
