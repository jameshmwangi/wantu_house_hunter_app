# Sidekiq configuration — only loaded when Sidekiq is actually being used.
# Currently the app uses :async queue adapter (no Redis needed).
#
# To re-enable Sidekiq in the future:
# 1. Set config.active_job.queue_adapter = :sidekiq in the environment file
# 2. Uncomment the lines below
# 3. Ensure REDIS_URL is set or Redis is running on localhost:6379
#
# Sidekiq.configure_server do |config|
#   config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
# end
#
# Sidekiq.configure_client do |config|
#   config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
# end
