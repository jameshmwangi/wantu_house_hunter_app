FactoryBot.define do
  factory :viewing_appointment do
    association :listing
    association :home_seeker, factory: :user
    association :agent, factory: [:user, :agent]
    scheduled_at { 3.days.from_now }
    fee_amount { 500 }
    fee_status { "unpaid" }
    status { "pending" }

    trait :confirmed do
      status { "confirmed" }
    end

    trait :completed do
      status { "completed" }
      fee_status { "paid" }
    end
  end
end
