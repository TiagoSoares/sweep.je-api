FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { :organizer }

    # public_id is assigned by the model; let it generate.

    factory :admin do
      role { :admin }
    end
  end
end
