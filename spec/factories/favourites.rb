FactoryBot.define do
  factory :favourite do
    association :user
    association :listing
  end
end
