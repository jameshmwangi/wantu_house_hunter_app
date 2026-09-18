class PropertyComment < ApplicationRecord
  belongs_to :listing
  belongs_to :author,         class_name: "User",            foreign_key: :author_id
  belongs_to :parent_comment, class_name: "PropertyComment",
                              foreign_key: :parent_comment_id, optional: true

  has_many :replies, class_name: "PropertyComment",
                     foreign_key: :parent_comment_id, dependent: :destroy

  validates :body, presence: { message: "Comment can't be blank" }
end
