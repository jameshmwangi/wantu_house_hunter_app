FactoryBot.define do
  factory :payment_attempt do
    association :viewing_appointment
    payment_method { "mpesa" }
    outcome { "success" }
    payment_reference { "WTU-#{SecureRandom.hex(6).upcase}" }

    trait :failed do
      outcome { "failed" }
      payment_reference { nil }
    end
  end
end
