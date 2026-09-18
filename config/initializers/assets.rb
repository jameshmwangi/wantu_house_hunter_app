# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# RailsAdmin SCSS source (npm package) — needed for sassc-rails to compile
# the gem's application.scss.erb which imports rails_admin/styles/*.
Rails.application.config.assets.paths << Rails.root.join("node_modules", "rails_admin", "src")

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w[rails_admin/application.css rails_admin/application.js rails_admin_custom.css]
