FactoryBot.define do
  factory :competition_template do
    sequence(:name) { |n| "Competition #{n}" }
    sequence(:slug) { |n| "competition-#{n}" }
    category { "football" }
    year { 2026 }
    status { :published }

    trait :with_entries do
      transient { entries_count { 4 } }
      after(:create) do |template, evaluator|
        evaluator.entries_count.times do |i|
          create(:template_entry, competition_template: template, position: i + 1, name: "Team #{i + 1}")
        end
      end
    end
  end
end
