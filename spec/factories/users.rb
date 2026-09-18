FactoryBot.define do
  factory :user do
    full_name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password1" }
    password_confirmation { "Password1" }
    role { "home_seeker" }

    trait :agent do
      role { "agent" }
    end

    trait :landlord do
      role { "landlord" }
    end

    trait :admin do
      role { "admin" }
    end
  end
end
