require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    describe 'full_name' do
      it 'is valid when present' do
        user = build(:user, full_name: 'Jane Doe')
        expect(user).to be_valid
      end

      it 'is invalid when blank' do
        user = build(:user, full_name: '')
        expect(user).not_to be_valid
        expect(user.errors[:full_name]).to include("can't be blank")
      end

      it 'is invalid when nil' do
        user = build(:user, full_name: nil)
        expect(user).not_to be_valid
        expect(user.errors[:full_name]).to include("can't be blank")
      end
    end

    describe 'role' do
      it 'is valid with home_seeker' do
        expect(build(:user, role: 'home_seeker')).to be_valid
      end

      it 'is valid with agent' do
        expect(build(:user, role: 'agent')).to be_valid
      end

      it 'is valid with landlord' do
        expect(build(:user, role: 'landlord')).to be_valid
      end

      it 'is valid with admin' do
        expect(build(:user, role: 'admin')).to be_valid
      end

      it 'is invalid with an unknown role' do
        user = build(:user, role: 'superuser')
        expect(user).not_to be_valid
        expect(user.errors[:role]).to include('is not included in the list')
      end

      it 'is invalid when role is blank' do
        user = build(:user, role: '')
        expect(user).not_to be_valid
        expect(user.errors[:role]).to include("can't be blank")
      end
    end

    describe 'password_complexity' do
      it 'is valid with uppercase, lowercase, and digit' do
        expect(build(:user, password: 'Password1', password_confirmation: 'Password1')).to be_valid
      end

      it 'is invalid without an uppercase letter' do
        user = build(:user, password: 'password1', password_confirmation: 'password1')
        expect(user).not_to be_valid
        expect(user.errors[:password].join).to match(/uppercase/i).or match(/complexity/i)
      end

      it 'is invalid without a lowercase letter' do
        user = build(:user, password: 'PASSWORD1', password_confirmation: 'PASSWORD1')
        expect(user).not_to be_valid
      end

      it 'is invalid without a digit' do
        user = build(:user, password: 'Password', password_confirmation: 'Password')
        expect(user).not_to be_valid
      end

      it 'is invalid when shorter than 8 characters' do
        user = build(:user, password: 'Pass1', password_confirmation: 'Pass1')
        expect(user).not_to be_valid
      end
    end

    describe 'avatar' do
      let(:user) { build(:user) }

      it 'is valid without an avatar attached' do
        expect(user).to be_valid
      end

      it 'is valid with a PNG avatar under 5MB' do
        user.avatar.attach(
          io: StringIO.new('fakepngdata'),
          filename: 'avatar.png',
          content_type: 'image/png'
        )
        expect(user).to be_valid
      end

      it 'is invalid with an unsupported content type (PDF)' do
        user.avatar.attach(
          io: StringIO.new('fakepdfdata'),
          filename: 'avatar.pdf',
          content_type: 'application/pdf'
        )
        expect(user).not_to be_valid
        expect(user.errors[:avatar].join).to match(/png|jpeg|webp|type/i)
      end

      it 'is invalid when avatar exceeds 5MB' do
        user.avatar.attach(
          io: StringIO.new('x' * 6.megabytes),
          filename: 'big.png',
          content_type: 'image/png'
        )
        expect(user).not_to be_valid
        expect(user.errors[:avatar].join).to match(/5|size|large/i)
      end
    end
  end

  describe 'role helpers' do
    it '#admin? is true for admin role' do
      expect(build(:user, :admin).admin?).to be true
    end

    it '#agent? is true for agent role' do
      expect(build(:user, :agent).agent?).to be true
    end

    it '#property_manager? is true for agents and landlords' do
      expect(build(:user, :agent).property_manager?).to be true
      expect(build(:user, :landlord).property_manager?).to be true
      expect(build(:user).property_manager?).to be false
    end
  end
end
