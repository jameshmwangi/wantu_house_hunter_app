# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
# frozen_string_literal: true

puts "\n== Wantu Seed =="

# Change counts here to scale the dataset
LISTING_CONFIGS = [
  { need_type: 'rent', use_case: 'house',       count: 10, featured: 1, drafts: 1 },
  { need_type: 'buy',  use_case: 'house',       count:  5, featured: 1, drafts: 1 },
  { need_type: 'bnb',  use_case: 'house',       count:  4, featured: 1, drafts: 0 },
  { need_type: 'rent', use_case: 'office',      count:  3, featured: 1, drafts: 0 },
  { need_type: 'rent', use_case: 'event_venue', count:  2, featured: 0, drafts: 0 },
].freeze

#  Users -

USERS_DATA = [
  { full_name: 'Wantu Admin',    email: 'admin@wantu.africa',    phone: '+254700000001', role: 'admin',       password: 'OneTwo@admin123' },
  { full_name: 'Abdalla Juma',   email: 'abdalla@wantu.africa',  phone: '+254711000001', role: 'agent',       password: 'OneTwo@123' },
  { full_name: 'Njeri Kamau',    email: 'njeri@wantu.africa',    phone: '+254711000002', role: 'agent',       password: 'OneTwo@123' },
  { full_name: 'David Mwangi',   email: 'david@wantu.africa',    phone: '+254711000003', role: 'agent',       password: 'OneTwo@123' },
  { full_name: 'Grace Wanjiru',  email: 'grace@wantu.africa',    phone: '+254711000004', role: 'landlord',    password: 'OneTwo@123' },
  { full_name: 'James Ochieng',  email: 'james@wantu.africa',    phone: '+254711000005', role: 'landlord',    password: 'OneTwo@123' },
  { full_name: 'Lucy Muthoni',   email: 'lucy@wantu.africa',     phone: '+254711000006', role: 'landlord',    password: 'OneTwo@123' },
  { full_name: 'Brian Otieno',   email: 'brian@wantu.africa',    phone: '+254722000001', role: 'home_seeker', password: 'OneTwo@123' },
  { full_name: 'Fatuma Hassan',  email: 'fatuma@wantu.africa',   phone: '+254722000002', role: 'home_seeker', password: 'OneTwo@123' },
  { full_name: 'Sarah Kiprop',   email: 'sarah@wantu.africa',    phone: '+254722000003', role: 'home_seeker', password: 'OneTwo@123' },
].freeze

#  Locations 

LOCATIONS_DATA = [
  { area_name: 'Westlands',    sub_county: 'Westlands',     county: 'Nairobi', country: 'Kenya' },
  { area_name: 'Karen',        sub_county: "Lang'ata",      county: 'Nairobi', country: 'Kenya' },
  { area_name: 'Kilimani',     sub_county: 'Dagoretti',     county: 'Nairobi', country: 'Kenya' },
  { area_name: 'Rongai',       sub_county: 'Ongata Rongai', county: 'Kajiado', country: 'Kenya' },
  { area_name: 'Ruaka',        sub_county: 'Limuru',        county: 'Kiambu',  country: 'Kenya' },
  { area_name: 'Kileleshwa',   sub_county: 'Dagoretti',     county: 'Nairobi', country: 'Kenya' },
  { area_name: 'Lavington',    sub_county: 'Dagoretti',     county: 'Nairobi', country: 'Kenya' },
  { area_name: 'South B',      sub_county: 'Makadara',      county: 'Nairobi', country: 'Kenya' },
  { area_name: 'South C',      sub_county: 'Langata',       county: 'Nairobi', country: 'Kenya' },
  { area_name: 'Juja',         sub_county: 'Juja',          county: 'Kiambu',  country: 'Kenya' },
  { area_name: 'Mombasa Road', sub_county: 'Embakasi',      county: 'Nairobi', country: 'Kenya' },
  { area_name: 'Kasarani',     sub_county: 'Kasarani',      county: 'Nairobi', country: 'Kenya' },
  { area_name: 'Nyali',        sub_county: 'Kisauni',       county: 'Mombasa', country: 'Kenya' },
  { area_name: 'Bamburi',      sub_county: 'Kisauni',       county: 'Mombasa', country: 'Kenya' },
  { area_name: 'Diani',        sub_county: 'Msambweni',     county: 'Kwale',   country: 'Kenya' },
  { area_name: 'Old Town',     sub_county: 'Mvita',         county: 'Mombasa', country: 'Kenya' },
].freeze

#  Listing pools 

ROOM_LAYOUTS = {
  'house'       => %w[bedsitter studio single_room one_bedroom two_bedroom three_bedroom],
  'office'      => %w[shared studio one_bedroom two_bedroom],
  'event_venue' => %w[shared],
}.freeze

PRICE_RANGES = {
  %w[rent house]       => (10_000..90_000).step(5_000).to_a,
  %w[buy  house]       => (2_500_000..30_000_000).step(500_000).to_a,
  %w[bnb  house]       => (2_500..8_000).step(500).to_a,
  %w[rent office]      => (50_000..250_000).step(10_000).to_a,
  %w[rent event_venue] => (5_000..40_000).step(1_000).to_a,
}.freeze

VIEWING_FEES = [200, 300, 400, 500, 1_000].freeze

BUILDING_SUFFIXES = {
  'house'       => %w[Court Apartments Heights Gardens Residences Villas Park Suites],
  'office'      => ['Towers', 'Business Park', 'Office Suites', 'Centre', 'Plaza'],
  'event_venue' => %w[Centre Hall Grounds Pavilion],
}.freeze

# One representative description per context
DESCRIPTIONS = {
  %w[rent house] => [
    'Spacious apartment with open-plan living, modern finishes, and secure parking. Water and garbage collection included. Ideal for young professionals or small families looking for comfort in a well-connected neighbourhood.',
    'Well-maintained unit in a quiet compound with 24-hour security, borehole backup, and one parking bay. Walking distance to major bus routes and shopping centres.',
  ],
  %w[buy house] => [
    'A charming home set on a lush garden with a large kitchen, servant quarters, and ample parking. Perfect for families seeking tranquillity without sacrificing proximity to the city.',
    'Investment-grade unit currently tenanted with a steady rental yield. Ideal for first-time buyers or investors looking for an affordable entry into the Nairobi market.',
  ],
  %w[bnb house] => [
    'Stylish BnB with Netflix, high-speed Wi-Fi, and a fully stocked kitchen. Self-check-in available via keypad. Perfect for solo travellers and digital nomads on extended stays.',
  ],
  %w[rent office] => [
    'Premium open-plan office with fibre internet, a dedicated conference room, and backup power. Suitable for tech startups, agencies, and growing consultancies.',
  ],
  %w[rent event_venue] => [
    'Versatile event space seating up to 200 guests, equipped with a PA system, staging area, prep kitchen, and ample parking. Suitable for weddings, corporate events, and community gatherings.',
  ],
}.freeze

REVIEW_TEMPLATES = [
  { rating: 5, title: 'Excellent service',   body: 'Very professional and responsive agent.' },
  { rating: 4, title: 'Great experience',    body: 'Found me a great place quickly.' },
  { rating: 3, title: 'Decent',              body: 'Good but could communicate better.' },
  { rating: 5, title: 'Highly recommend',    body: 'Fast responses and honest listings.' },
  { rating: 4, title: 'Solid landlord',      body: 'Helped me navigate the process easily.' },
  { rating: 2, title: 'Below expectations',  body: 'Listing photos did not match reality.' },
].freeze

COMMENT_QUESTIONS = [
  'Is the parking included in the rent?',
  'How far is this from the nearest matatu stage?',
  'Is the price negotiable?',
  'Are pets allowed?',
  'What is the minimum lease term?',
  'Is water and electricity included?',
].freeze

COMMENT_REPLIES = [
  'Yes, one parking bay is included.',
  'About 5 minutes walk to the main stage.',
  'Slightly negotiable for long-term tenants.',
  'Unfortunately pets are not allowed.',
  'Minimum lease is 6 months.',
  'Water is included; electricity is metered separately.',
].freeze

#  Helpers 

def seed!(model, find_attrs, extra_attrs = {})
  model.find_or_create_by!(find_attrs) { |r| extra_attrs.each { |k, v| r.send(:"#{k}=", v) } }
end

def price_period(need_type, use_case)
  return 'total' if need_type == 'buy'
  return 'night' if need_type == 'bnb'
  return 'day'   if use_case == 'event_venue'
  'month'
end

def generate_title(need_type, use_case, room_layout, area_name)
  label = room_layout.sub('one_', '1-').sub('two_', '2-').sub('three_', '3-')
                     .sub('_bedroom', '-Bed').gsub('_', ' ').split.map(&:capitalize).join(' ')
  case use_case
  when 'office'      then "#{label} Office in #{area_name}"
  when 'event_venue' then "Event Hall in #{area_name}"
  else need_type == 'bnb' ? "#{label} BnB in #{area_name}" : "#{label} in #{area_name}"
  end
end

def unique_title(base, counts)
  counts[base] += 1
  counts[base] == 1 ? base : "#{base} (#{counts[base]})"
end

#  Seed  

puts "Seeding users..."
all_users = USERS_DATA.map do |u|
  seed!(User, { email: u[:email] },
        full_name: u[:full_name], password: u[:password],
        role: u[:role], phone_number: u[:phone])
end

managers = all_users.select { |u| %w[agent landlord].include?(u.role) }
seekers  = all_users.select { |u| u.role == 'home_seeker' }

puts "Seeding locations..."
locations = LOCATIONS_DATA.map do |a|
  seed!(Location, { area_name: a[:area_name] },
        county: a[:county], sub_county: a[:sub_county], country: a[:country])
end

puts "Seeding listings..."
title_counts = Hash.new(0)
all_listings = []

LISTING_CONFIGS.each do |cfg|
  need_type = cfg[:need_type]
  use_case  = cfg[:use_case]
  featured_count  = cfg.fetch(:featured, 0)
  draft_count     = cfg.fetch(:drafts, 0)
  published_count = cfg[:count] - featured_count - draft_count

  queue = (['featured'] * featured_count) + (['draft'] * draft_count) + (['published'] * published_count)

  queue.each do |slot|
    is_featured = slot == 'featured'
    location    = locations.sample
    room_layout = ROOM_LAYOUTS.fetch(use_case, ['shared']).sample
    title       = unique_title(generate_title(need_type, use_case, room_layout, location.area_name), title_counts)

    all_listings << seed!(Listing, { title: title },
      description:   DESCRIPTIONS.fetch([need_type, use_case], DESCRIPTIONS[%w[rent house]]).sample,
      need_type:     need_type,
      use_case:      use_case,
      room_layout:   room_layout,
      price:         PRICE_RANGES.fetch([need_type, use_case], [50_000]).sample,
      price_period:  price_period(need_type, use_case),
      building_name: "#{location.area_name} #{BUILDING_SUFFIXES.fetch(use_case, BUILDING_SUFFIXES['house']).sample}",
      status:        is_featured ? 'published' : slot,
      featured:      is_featured,
      viewing_fee:   slot == 'draft' ? 0 : VIEWING_FEES.sample,
      bathrooms:     use_case == 'event_venue' ? 2 : [1, 1, 1, 2, 2, 3].sample,
      location:      location,
      user:          managers.sample)
  end
end

# Ensure Juja and Rongai have listings for location cards
puts "Seeding specific listings for Juja and Rongai..."
juja_location = locations.find { |loc| loc.area_name == 'Juja' }
rongai_location = locations.find { |loc| loc.area_name == 'Rongai' }

[juja_location, rongai_location].compact.each do |location|
  # Add 3 rent listings for each
  3.times do
    room_layout = %w[bedsitter one_bedroom two_bedroom].sample
    title = unique_title(generate_title('rent', 'house', room_layout, location.area_name), title_counts)
    
    all_listings << seed!(Listing, { title: title },
      description:   DESCRIPTIONS[%w[rent house]].sample,
      need_type:     'rent',
      use_case:      'house',
      room_layout:   room_layout,
      price:         PRICE_RANGES[%w[rent house]].sample,
      price_period:  'month',
      building_name: "#{location.area_name} #{BUILDING_SUFFIXES['house'].sample}",
      status:        'published',
      featured:      false,
      viewing_fee:   VIEWING_FEES.sample,
      bathrooms:     [1, 1, 2].sample,
      location:      location,
      user:          managers.sample)
  end
end

puts "Seeding property images..."
available_images = Dir[Rails.root.join('db', 'seed_images', '*.png')].sort

if available_images.empty?
  puts "  ⚠  No seed images found in db/seed_images/ — skipping image seeding"
else
  all_listings.each do |listing|
    # Remove orphaned PropertyImage records (created but never attached)
    listing.property_images.select { |pi| !pi.image.attached? }.each(&:destroy)

    attached_count = listing.property_images.count { |pi| pi.image.attached? }
    next if attached_count >= available_images.length

    available_images.each_with_index do |img_path, i|
      filename = File.basename(img_path)
      pi = listing.property_images.find_or_create_by!(image_url: filename)
      next if pi.image.attached?
      pi.image.attach(
        io:           File.open(img_path),
        filename:     "listing_#{listing.id}_#{i}_#{filename}",
        content_type: 'image/png'
      )
    end
  end
end

puts "Seeding favourites..."
published = all_listings.select { |l| l.status == 'published' }
seekers.each { |s| published.sample(3).each { |l| seed!(Favourite, { user: s, listing: l }) } }

puts "Seeding viewing appointments..."
appt_meta = [
  { fee_status: 'paid',   status: 'confirmed' },
  { fee_status: 'unpaid', status: 'pending'   },
  { fee_status: 'paid',   status: 'completed' },
  { fee_status: 'unpaid', status: 'pending'   },
  { fee_status: 'paid',   status: 'confirmed' },
  { fee_status: 'unpaid', status: 'declined'  },
]
appointments = published.sample(appt_meta.length).each_with_index.map do |listing, i|
  m = appt_meta[i]
  seed!(ViewingAppointment, { listing: listing, home_seeker: seekers[i % seekers.length] },
        agent: managers[i % managers.length], scheduled_at: (i + 1).days.from_now,
        fee_amount: listing.viewing_fee, fee_status: m[:fee_status], status: m[:status])
end

puts "Seeding agent reviews..."
seekers.each_with_index do |seeker, si|
  managers.sample(2).each_with_index do |manager, mi|
    t = REVIEW_TEMPLATES[(si * 2 + mi) % REVIEW_TEMPLATES.length]
    seed!(AgentReview, { agent: manager, author: seeker }, rating: t[:rating], title: t[:title], body: t[:body])
  end
end

puts "Seeding property comments..."
parent_comments = published.first(6).each_with_index.map do |listing, i|
  seed!(PropertyComment, { listing: listing, author: seekers[i % seekers.length],
                            parent_comment_id: nil, body: COMMENT_QUESTIONS[i % COMMENT_QUESTIONS.length] })
end
parent_comments.each_with_index do |pc, i|
  seed!(PropertyComment, { listing: pc.listing, author: managers[i % managers.length],
                            parent_comment_id: pc.id, body: COMMENT_REPLIES[i % COMMENT_REPLIES.length] })
end

puts "Seeding payment attempts..."
appointments.each_with_index do |appt, i|
  outcome = appt.fee_status == 'paid' ? 'success' : 'failed'
  seed!(PaymentAttempt, { viewing_appointment: appt, outcome: outcome },
        payment_method: i.even? ? 'mpesa' : 'card',
        payment_reference: outcome == 'success' ? "WANTU#{SecureRandom.hex(5).upcase}" : nil)
end

puts "\n== Seed complete =="
puts "Admin:      admin@wantu.africa / OneTwo@admin123"
puts "Agent:      abdalla@wantu.africa / OneTwo@123"
puts "HomeSeeker: brian@wantu.africa / OneTwo@123"
puts "Seeded: #{User.count} users, #{Location.count} locations, #{Listing.count} listings"
puts "        #{PropertyImage.count} images, #{Favourite.count} favourites, #{ViewingAppointment.count} appointments"
puts "        #{AgentReview.count} reviews, #{PropertyComment.count} comments, #{PaymentAttempt.count} payments"