class Users::RegistrationsController < Devise::RegistrationsController
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
