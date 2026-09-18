class AgentReview < ApplicationRecord
  belongs_to :agent,  class_name: "User", foreign_key: :agent_id
  belongs_to :author, class_name: "User", foreign_key: :author_id

  validates :rating, presence: true,
                     numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :body, presence: true
end
