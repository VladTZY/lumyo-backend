# POST /transcriptions with a multipart `audio` file (and an optional
# ISO-639-1 `language` hint). Responds with { text:, model: }.
class TranscriptionsController < ApplicationController
  # OpenRouter rejects inline audio over 25 MB, about 26 minutes of 128 kbps.
  MAX_BYTES = 25.megabytes

  # Content type => format name the transcription providers expect.
  FORMATS = {
    "audio/mp4" => "m4a", "audio/m4a" => "m4a", "audio/x-m4a" => "m4a", "video/mp4" => "m4a",
    "audio/aac" => "aac",
    "audio/webm" => "webm", "video/webm" => "webm",
    "audio/ogg" => "ogg",
    "audio/mpeg" => "mp3", "audio/mp3" => "mp3",
    "audio/wav" => "wav", "audio/x-wav" => "wav", "audio/wave" => "wav",
    "audio/flac" => "flac"
  }.freeze
  EXTENSIONS = %w[m4a mp4 aac webm ogg mp3 wav flac].freeze

  # Every request is a paid provider call.
  rate_limit to: 30, within: 10.minutes, by: -> { current_user.id },
    with: -> { render json: { error: "Too many recordings at once. Wait a minute and try again." }, status: :too_many_requests }

  def self.max_bytes = MAX_BYTES

  def create
    upload = params[:audio]
    unless upload.respond_to?(:read)
      return render json: { error: "Attach a recording to transcribe." }, status: :unprocessable_entity
    end

    format = format_for(upload)
    unless format
      return render json: { error: "That audio format isn't supported. Record again in the app." }, status: :unprocessable_entity
    end

    if upload.size > self.class.max_bytes
      return render json: { error: "That recording is too long. Keep it under about 25 minutes." }, status: :content_too_large
    end

    result = Transcriber.default.call(audio: upload.read, format: format, language: language_hint)
    render json: { text: result.text, model: result.model }
  rescue Transcription::NoSpeech
    render json: { error: "No speech found in the recording." }, status: :unprocessable_entity
  rescue Transcription::ProviderError => e
    # Provider messages can carry internals; log them, show something generic.
    Rails.logger.error("[Transcriptions] #{e.message}")
    render json: { error: "Couldn't transcribe the recording. Try again." }, status: :bad_gateway
  end

  private

  def format_for(upload)
    type = upload.content_type.to_s.split(";").first.to_s.strip.downcase
    return FORMATS[type] if FORMATS.key?(type)
    return nil unless type == "application/octet-stream"

    ext = File.extname(upload.original_filename.to_s).delete(".").downcase
    return nil unless EXTENSIONS.include?(ext)

    ext == "mp4" ? "m4a" : ext
  end

  def language_hint
    lang = params[:language].to_s.downcase
    lang.match?(/\A[a-z]{2}\z/) ? lang : nil
  end
end
