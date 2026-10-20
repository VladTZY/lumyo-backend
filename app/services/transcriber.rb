# Turns a voice recording into text by trying a chain of models in order.
#
# Swapping the model is configuration: set TRANSCRIPTION_MODELS to a
# comma-separated list of OpenRouter model slugs, first choice first. The
# next model is used only when one fails in a way another model could fix
# (an unsupported format, an outage). Swapping the provider means passing a
# different client with the same #transcribe signature.
#
# Defaults, chosen by testing m4a and webm in English and Romanian
# (Oct 2026): Whisper Large V3 Turbo was accurate in both languages, ~2s for
# a 5s clip and about 10x cheaper than the alternatives (~$0.012 per hour).
# Voxtral Mini was equally accurate, so it is the fallback.
class Transcriber
  DEFAULT_MODELS = %w[openai/whisper-large-v3-turbo mistralai/voxtral-mini-transcribe].freeze

  Result = Struct.new(:text, :model, keyword_init: true)

  def self.models_from_env(env = ENV)
    models = env.fetch("TRANSCRIPTION_MODELS", "").split(",").map(&:strip).reject(&:empty?)
    models.presence || DEFAULT_MODELS
  end

  def self.default
    new(client: Transcription::OpenRouterClient.new, models: models_from_env)
  end

  def initialize(client:, models:)
    raise ArgumentError, "Transcriber needs at least one model" if models.blank?

    @client = client
    @models = models
  end

  def call(audio:, format:, language: nil)
    last_error = nil

    @models.each do |model|
      text = @client.transcribe(audio: audio, format: format, model: model, language: language)
      raise Transcription::NoSpeech if text.blank?

      return Result.new(text: text, model: model)
    rescue Transcription::ProviderError => e
      raise unless e.retryable?

      Rails.logger.warn("[Transcriber] #{model} failed: #{e.message}; trying next model")
      last_error = e
    end

    raise last_error
  end
end
