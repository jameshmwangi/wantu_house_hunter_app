Rails.application.routes.draw do
  # Development-only tools
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: '/letter_opener'

    require 'sidekiq/web'
    mount Sidekiq::Web, at: '/sidekiq'
  end

  # Auth
  devise_for :users, controllers: { registrations: 'users/registrations' }

  # Guest login (evaluator access — signs in a pre-seeded user without credentials)
  post 'guest_login', to: 'guest_sessions#create', as: :guest_login

  # Admin — rails_admin (authenticated, admin-only)
  authenticate :user, ->(u) { u.admin? } do
    mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  end

  # Root
  root 'pages#home'

  # Listings (public)
  resources :listings, only: [:index, :show] do
    resources :property_comments, only: [:index, :create, :destroy], path: 'comments'
    resources :viewing_appointments, only: [:new, :create], path: 'appointments'
  end

  # Locations (public)
  resources :locations, only: [:index, :show]

  # Favourites
  resources :favourites, only: [:index, :create, :destroy]

  # Agent Reviews
  resources :agent_reviews, only: [:new, :create, :edit, :update, :destroy]

  # Dashboard (agents / landlords)
  get 'dashboard', to: 'dashboard#index', as: :dashboard
  namespace :dashboard do
    resources :listings, except: [:show] do
      member do
        patch :publish
        patch :hide
      end
      resources :property_images, only: [:create, :destroy], path: 'images'
    end
    resources :viewing_appointments, only: [:index, :update], path: 'appointments', as: :appointments
    resources :viewing_appointments, only: [] do
      member { post :release_escrow }
    end
    resources :payout_accounts, only: [:index, :create, :destroy]
    resources :withdrawals, only: [:index, :create]
  end

  # Account
  resource :account, only: [:show, :edit, :update], controller: 'accounts'

  # Agent Public Profile
  get 'agents/:id', to: 'agents#show', as: :agent_profile

  # Payment Attempts
  resources :payment_attempts, only: [:new, :create]

  namespace :api do
    namespace :v1 do
      post "visits/:id/confirm", to: "visits#confirm"

      # Jenga payment routes
      # Initiate collection (STK push / MoMo) for a specific escrow transaction
      post "escrow_transactions/:escrow_transaction_id/pay", to: "payments#create",
           as: :escrow_transaction_pay

      # Jenga unified callback URL (single IPN registered in JengaHQ for collection & payouts)
      post "payments/jenga_ipn", to: "payments#ipn", as: :jenga_ipn

      # Backwards-compatible aliases in case previous sandbox registrations point here
      post "payments/ipn", to: "payments#ipn", as: :payments_ipn
      post "payouts/ipn",  to: "payments#ipn", as: :payouts_ipn
    end
  end


  # Error pages
  match '/404', to: 'errors#not_found', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end
