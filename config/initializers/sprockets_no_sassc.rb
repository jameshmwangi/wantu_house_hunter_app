# dartsass-rails handles SCSS compilation (stylesheets/ -> builds/).
# Sprockets 4 auto-discovers .scss files and tries to compile them with
# its built-in SasscProcessor, which requires the native `sassc` gem.
# On Windows + Ruby 3.3, the sassc native library is unavailable / broken.
#
# Fix: Unregister Sprockets' SCSS/Sass transformers so it treats .scss files
# as plain files rather than trying to compile them with sassc.
# The pre-compiled CSS in app/assets/builds/ is what actually gets served.

require "sprockets"

module Sprockets
  module Transformers
    def unregister_transformer(from, to)
      self.config = hash_reassoc(config, :registered_transformers) do |transformers|
        transformers.reject { |t| t.from == from && t.to == to }
      end
      compute_transformers!(self.config[:registered_transformers])
    end
  end
end

Sprockets.unregister_transformer("text/scss", "text/css")
Sprockets.unregister_transformer("text/sass", "text/css")
Sprockets.unregister_transformer("application/scss+ruby", "text/scss")
Sprockets.unregister_transformer("application/sass+ruby", "text/sass")

Rails.application.config.assets.configure do |env|
  env.unregister_transformer("text/scss", "text/css")
  env.unregister_transformer("text/sass", "text/css")
  env.unregister_transformer("application/scss+ruby", "text/scss")
  env.unregister_transformer("application/sass+ruby", "text/sass")
end

