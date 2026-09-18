FactoryBot.define do
  factory :property_comment do
    association :listing
    association :author, factory: :user
    body { "Great location and value for money." }
    parent_comment { nil }
  end
end
