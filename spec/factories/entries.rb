FactoryBot.define do
  factory :entry do
    association :sweepstake
    sequence(:name) { |n| "Team #{n}" }
  end
end
