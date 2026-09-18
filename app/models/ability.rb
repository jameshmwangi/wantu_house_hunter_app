# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # unauthenticated user (not logged in)

    # Everyone can read published listings and locations
    can :read, Listing, status: 'published'
    can :read, Location
    can :read, AgentReview
    can :read, PropertyComment

    return unless user.persisted?

    # All signed-in users can create a listing (home_seeker triggers auto-upgrade)
    can :create, Listing
    can :create, Favourite
    can :destroy, Favourite, user_id: user.id
    can :read, Favourite, user_id: user.id
    can :create, PropertyComment
    can :destroy, PropertyComment, author_id: user.id
    can :create, ViewingAppointment
    cannot :create, ViewingAppointment do |appointment|
      appointment.listing&.user_id == user.id
    end
    can :read, ViewingAppointment, home_seeker_id: user.id
    can :create, AgentReview
    can [:update, :destroy], AgentReview, author_id: user.id
    can :create, PaymentAttempt

    if user.property_manager?
      # Agents / landlords
      can [:update, :destroy, :publish, :hide], Listing, user_id: user.id
      can :read, Listing, user_id: user.id # can see own drafts
      can :read, ViewingAppointment, agent_id: user.id
      can [:confirm, :decline, :complete], ViewingAppointment, agent_id: user.id
      can :access, :dashboard

      # Escrow payout management
      can :manage, PayoutAccount, agent_id: user.id
      can [:read, :create], Withdrawal, agent_id: user.id
    end

    if user.admin?
      can :manage, :all
      can :access, :admin_dashboard
    end
  end
end
