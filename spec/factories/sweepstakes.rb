FactoryBot.define do
  factory :sweepstake do
    association :user
    sequence(:name) { |n| "Office Sweepstake #{n}" }
    description { "World Cup draw" }
    timezone { "Europe/London" }
    draw_at { 1.week.from_now }
    status { :open }

    trait :locked do
      status { :locked }
    end

    trait :with_entries do
      transient { entries_count { 8 } }
      after(:create) do |sweepstake, evaluator|
        evaluator.entries_count.times do |i|
          create(:entry, sweepstake:, position: i + 1)
        end
      end
    end
  end
end
