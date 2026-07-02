# Use a dedicated Redis DB for Lumio's Sidekiq. Sharing redis db 0 with
# other local apps means their Sidekiq workers poll the same "default"
# queue and steal Lumio's jobs (and vice versa) — jobs then fail with
# UnknownJobClassError or sit unprocessed.
redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2") }

Sidekiq.configure_server { |config| config.redis = redis_config }
Sidekiq.configure_client { |config| config.redis = redis_config }
