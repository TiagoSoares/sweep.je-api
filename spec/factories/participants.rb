FactoryBot.define do
  factory :participant do
    association :sweepstake
    sequence(:name) { |n| "Participant #{n}" }
  end
end
