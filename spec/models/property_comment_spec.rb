require 'rails_helper'

RSpec.describe PropertyComment, type: :model do
  let(:listing) { create(:listing) }
  let(:author)  { create(:user) }

  describe 'validations' do
    describe 'body' do
      it 'is valid when present' do
        comment = build(:property_comment, listing: listing, author: author, body: 'Looks great')
        expect(comment).to be_valid
      end

      it 'is invalid when blank' do
        comment = build(:property_comment, listing: listing, author: author, body: '')
        expect(comment).not_to be_valid
        expect(comment.errors[:body]).to include("Comment can't be blank")
      end

      it 'is invalid when nil' do
        comment = build(:property_comment, listing: listing, author: author, body: nil)
        expect(comment).not_to be_valid
        expect(comment.errors[:body]).to include("Comment can't be blank")
      end
    end

    describe 'associations' do
      it 'requires a listing' do
        comment = build(:property_comment, listing: nil, author: author)
        expect(comment).not_to be_valid
      end

      it 'requires an author' do
        comment = build(:property_comment, listing: listing, author: nil)
        expect(comment).not_to be_valid
      end

      it 'allows a nil parent_comment (top-level comment)' do
        comment = build(:property_comment, listing: listing, author: author, parent_comment: nil)
        expect(comment).to be_valid
      end

      it 'allows nested replies via parent_comment' do
        parent = create(:property_comment, listing: listing, author: author)
        reply  = build(:property_comment, listing: listing, author: author, parent_comment: parent)
        expect(reply).to be_valid
      end

      it 'destroys replies when the parent comment is destroyed' do
        parent = create(:property_comment, listing: listing, author: author)
        create(:property_comment, listing: listing, author: author, parent_comment: parent)
        expect { parent.destroy }.to change { PropertyComment.count }.by(-2)
      end
    end
  end
end
