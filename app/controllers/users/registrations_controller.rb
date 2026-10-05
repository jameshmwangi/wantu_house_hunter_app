class Users::RegistrationsController < Devise::RegistrationsController
  # Assign a random uid for normal (password-based) sign-ups so the
  # unique index on [uid, provider] doesn't reject blank-uid duplicates.
  def build_resource(hash = {})
    hash[:uid]      = User.create_unique_string
    hash[:provider] = "email"
    super
  end

  def create
    super do |resource|
      if resource.persisted?
        begin
          UserMailer.welcome_email(resource).deliver_now
        rescue => e
          Rails.logger.error("[UserMailer] welcome_email failed: #{e.class}: #{e.message}")
        end
      end
    end
  end
end
