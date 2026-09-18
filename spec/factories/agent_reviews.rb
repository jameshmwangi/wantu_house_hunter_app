FactoryBot.define do
  factory :agent_review do
    agent { nil }
    author { nil }
    rating { 1 }
    title { "MyString" }
    body { "MyText" }
  end
end
