RubyLLM.configure do |config|
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]

  # Default is 300s with 3 retries on POST — a single bad call could occupy
  # a Sidekiq thread for many minutes. Fail fast instead.
  config.request_timeout = 60
  config.max_retries = 2
end
