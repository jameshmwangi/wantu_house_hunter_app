RailsAdmin.config do |config|
  config.asset_source = :sprockets

  ### Mount path
  config.main_app_name = ['Wantu', 'Admin']

  ### Authentication — Devise
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method(&:current_user)

  ### Authorization — CanCanCan
  config.authorize_with :cancancan

  ### Pagination
  config.default_items_per_page = 25

  ### Which models appear in sidebar
  config.included_models = %w[
    User
    Listing
    Location
    ViewingAppointment
    PaymentAttempt
    Favourite
    PropertyImage
    AgentReview
    PropertyComment
  ]

  # ── Actions ─────────────────────────────────────────────────────
  config.actions do
    dashboard do
      controller do
        proc do
          @stats = {
            total_users:       User.count,
            active_listings:   Listing.published.count,
            total_bookings:    ViewingAppointment.count,
            payments_received: PaymentAttempt
                                 .successful
                                 .joins(:viewing_appointment)
                                 .sum('viewing_appointments.fee_amount')
          }

          @finance = {}
          @finance[:total_processed] = @stats[:payments_received]

          @finance[:total_released] = ViewingAppointment
            .status_completed
            .joins(:payment_attempts)
            .where(payment_attempts: { outcome: 'success' })
            .sum(:fee_amount)

          @finance[:held_in_escrow] = ViewingAppointment
            .where(status: %w[awaiting_confirmation confirmed])
            .joins(:payment_attempts)
            .where(payment_attempts: { outcome: 'success' })
            .sum(:fee_amount)

          @recent_users    = User.order(created_at: :desc).limit(5)
          @recent_listings = Listing
                               .includes(:user, :location)
                               .order(created_at: :desc)
                               .limit(5)
        end
      end
    end
    index
    show
    new
    edit
    delete
    export
  end

  # ── USER ────────────────────────────────────────────────────────
  config.model 'User' do
    navigation_label 'Manage'
    weight 1

    list do
      field :id
      field :full_name
      field :email
      field :role do
        formatted_value do
          "<span class='role-badge role-badge--#{value}'>#{value.humanize}</span>".html_safe
        end
      end
      field :created_at do
        label 'Joined'
        formatted_value { value.strftime('%d %b %Y') }
      end
    end

    show do
      field :id
      field :full_name
      field :email
      field :phone_number
      field :role
      field :bio
      field :created_at
      field :listings
    end

    edit do
      field :full_name
      field :email
      field :phone_number
      field :role, :enum do
        enum { User::ROLES }
      end
      field :bio
    end
  end

  # ── LISTING ─────────────────────────────────────────────────────
  config.model 'Listing' do
    navigation_label 'Manage'
    weight 2
    label 'Property'
    label_plural 'Properties'

    list do
      field :id
      field :title
      field :user do
        label 'Agent'
      end
      field :need_type do
        label 'Type'
      end
      field :price do
        formatted_value { bindings[:view].number_with_delimiter(value.to_i) }
      end
      field :status do
        formatted_value do
          "<span class='status-badge status-badge--#{value}'>#{value.capitalize}</span>".html_safe
        end
      end
      field :featured do
        label 'Featured (sponsored)'
        formatted_value { value ? 'Yes' : 'No' }
      end
      field :created_at do
        label 'Listed'
        formatted_value { value.strftime('%d %b %Y') }
      end
    end

    show do
      field :id
      field :title
      field :description
      field :user
      field :location
      field :need_type
      field :use_case
      field :room_layout
      field :price
      field :price_period
      field :viewing_fee
      field :status
      field :featured
      field :created_at
    end

    edit do
      field :title
      field :description
      field :status, :enum do
        enum { Listing::STATUSES }
      end
      field :featured
      field :need_type, :enum do
        enum { Listing::NEED_TYPES }
      end
      field :use_case, :enum do
        enum { Listing::USE_CASES }
      end
      field :room_layout, :enum do
        enum { Listing::ROOM_LAYOUTS }
      end
      field :price
      field :price_period, :enum do
        enum { Listing::PRICE_PERIODS }
      end
      field :viewing_fee
      field :location
      field :user
    end
  end

  # ── LOCATION ────────────────────────────────────────────────────
  config.model 'Location' do
    navigation_label 'Manage'
    weight 3

    list do
      field :id
      field :area_name
      field :sub_county
      field :county
      field :country
    end

    edit do
      field :area_name
      field :sub_county
      field :county
      field :country
    end
  end

  # ── VIEWING APPOINTMENTS ────────────────────────────────────────
  config.model 'ViewingAppointment' do
    navigation_label 'Manage'
    weight 4
    label 'Booking'
    label_plural 'Bookings'

    list do
      field :id
      field :listing
      field :home_seeker do
        label 'Home Seeker'
        formatted_value { bindings[:object].home_seeker.full_name }
      end
      field :agent do
        formatted_value { bindings[:object].agent.full_name }
      end
      field :scheduled_at do
        formatted_value { value.in_time_zone('Nairobi').strftime('%d %b %Y %I:%M %p') }
      end
      field :status
      field :fee_status
      field :fee_amount do
        formatted_value { "Ksh #{bindings[:view].number_with_delimiter(value.to_i)}" }
      end
    end

    show do
      field :id
      field :listing
      field :home_seeker
      field :agent
      field :scheduled_at
      field :status
      field :fee_status
      field :fee_amount
      field :payment_attempts
    end

    edit do
      field :status, :enum do
        enum { %w[pending awaiting_confirmation confirmed declined completed] }
        help 'Only change status in exceptional circumstances (fraud, disputes)'
      end
    end
  end

  # ── PAYMENT ATTEMPTS ────────────────────────────────────────────
  config.model 'PaymentAttempt' do
    navigation_label 'Finances'
    weight 5
    label 'Payment'
    label_plural 'Payments'

    list do
      scopes [nil, :successful, :failed, :pending_outcome]

      field :id
      field :viewing_appointment do
        label 'Booking'
      end
      field :payment_method do
        formatted_value { value.humanize }
      end
      field :outcome do
        formatted_value do
          case value
          when 'success'
            "<span class='outcome-success'>✓ Success</span>".html_safe
          when 'failed'
            "<span class='outcome-failed'>✗ Failed</span>".html_safe
          when 'pending'
            "<span class='outcome-pending'>⏳ Pending</span>".html_safe
          end
        end
      end
      field :payment_reference
      field :created_at do
        label 'Date'
        formatted_value { value.in_time_zone('Nairobi').strftime('%d %b %Y %I:%M %p') }
      end
    end

    show do
      field :id
      field :viewing_appointment
      field :payment_method
      field :outcome
      field :payment_reference
      field :created_at
    end

    edit do
    end
  end

  # ── AGENT REVIEWS ───────────────────────────────────────────────
  config.model 'AgentReview' do
    navigation_label 'Manage'
    weight 6
    label 'Review'
    label_plural 'Reviews'

    list do
      field :id
      field :agent do
        formatted_value { bindings[:object].agent.full_name }
      end
      field :author do
        formatted_value { bindings[:object].author.full_name }
      end
      field :rating
      field :title
      field :created_at
    end

    edit do; end
  end

  # ── PROPERTY COMMENTS ───────────────────────────────────────────
  config.model 'PropertyComment' do
    navigation_label 'Manage'
    weight 7

    list do
      field :id
      field :listing
      field :author do
        formatted_value { bindings[:object].author.full_name }
      end
      field :body do
        formatted_value { bindings[:view].truncate(value, length: 60) }
      end
      field :created_at
    end

    edit do; end
  end

  # Hide from sidebar — managed via parent models
  config.model 'Favourite' do
    visible false
  end

  config.model 'PropertyImage' do
    visible false
  end
end
