FactoryBot.define do
  factory :listing do
    association :user, :agent
    association :location
    title { "Modern #{%w[1-Bedroom 2-Bedroom Studio Bedsitter].sample} in Westlands" }
    description { "A beautiful property with modern amenities." }
    need_type { "rent" }
    use_case { "house" }
    room_layout { "one_bedroom" }
    price { 25_000 }
    price_period { "month" }
    building_name { "Sunrise Apartments" }
    viewing_fee { 500 }
    status { "published" }
    featured { false }
    bathrooms { 1 }

    trait :draft do
      status { "draft" }
    end

    trait :hidden do
      status { "hidden" }
    end

    trait :featured do
      featured { true }
    end

    trait :for_sale do
      need_type { "buy" }
      price { 5_000_000 }
      price_period { "total" }
    end

    trait :bnb do
      need_type { "bnb" }
      price { 3_500 }
      price_period { "night" }
    end
  end
end
