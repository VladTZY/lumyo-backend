require "base64"

module Transcription
  # Speech-to-text through OpenRouter's /audio/transcriptions endpoint.
  #
  # Any object with the same #transcribe signature can replace this one in
  # Transcriber, so moving to another provider means writing one class like
  # this, not touching the controller or the app.
  class OpenRouterClient
    ENDPOINT = "https://openrouter.ai/api/v1/audio/transcriptions".freeze

    def initialize(api_key: ENV["OPENROUTER_API_KEY"], connection: nil, timeout: 60)
      @api_key = api_key
      @connection = connection || Faraday.new do |f|
        f.options.timeout = timeout
        f.options.open_timeout = 10
      end
    end

    # audio: raw bytes. format: container name the provider expects ("m4a",
    # "webm", ...). language: optional ISO-639-1 hint; auto-detected if nil.
    # Returns the transcript, stripped. Raises ProviderError.
    def transcribe(audio:, format:, model:, language: nil)
      body = {
        model: model,
        input_audio: { data: Base64.strict_encode64(audio), format: format },
        # Voice notes are personal: only route to providers that don't keep
        # or train on the audio.
        provider: { data_collection: "deny" }
      }
      body[:language] = language if language.present?

      response = @connection.post(ENDPOINT) do |req|
        req.headers["Authorization"] = "Bearer #{@api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = body.to_json
      end

      unless response.success?
        raise ProviderError.new("OpenRouter returned #{response.status} for #{model}", status: response.status)
      end

      text = parse_text(response.body)
      raise ProviderError.new("OpenRouter returned no transcript for #{model}", status: response.status) if text.nil?

      text.strip
    rescue Faraday::Error => e
      raise ProviderError.new("Couldn't reach OpenRouter for #{model} (#{e.class.name.demodulize}: #{e.message.to_s.first(120)})")
    end

    private

    def parse_text(raw)
      JSON.parse(raw.to_s)["text"]
    rescue JSON::ParserError
      nil
    end
  end
end
