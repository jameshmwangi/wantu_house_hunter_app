FactoryBot.define do
  factory :location do
    sequence(:area_name) { |n| "Area #{n}" }
    county { "Nairobi" }
    sub_county { "Westlands" }
    country { "Kenya" }
  end
end
