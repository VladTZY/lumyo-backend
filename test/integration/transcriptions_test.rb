require "test_helper"
require "devise/jwt/test_helpers"

class TranscriptionsTest < ActionDispatch::IntegrationTest
  Result = Transcriber::Result

  setup do
    @user = users(:one)
    @headers = Devise::JWT::TestHelpers.auth_headers({ "Accept" => "application/json" }, @user)
  end

  def audio(name = "voice.m4a", type = "audio/mp4")
    fixture_file_upload(name, type)
  end

  def with_transcriber(fake, &block)
    with_stub(Transcriber, :default, -> { fake }, &block)
  end

  class FakeTranscriber
    attr_reader :calls

    def initialize(outcome)
      @outcome = outcome
      @calls = []
    end

    def call(audio:, format:, language: nil)
      @calls << { bytes: audio.bytesize, format: format, language: language }
      raise @outcome if @outcome.is_a?(Exception)
      @outcome
    end
  end

  test "requires authentication" do
    post "/transcriptions", params: { audio: audio }, headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end

  test "returns the transcript and model for an uploaded recording" do
    fake = FakeTranscriber.new(Result.new(text: "Book the lab", model: "openai/whisper-large-v3-turbo"))
    with_transcriber(fake) do
      post "/transcriptions", params: { audio: audio, language: "en" }, headers: @headers
    end

    assert_response :ok
    assert_equal({ "text" => "Book the lab", "model" => "openai/whisper-large-v3-turbo" }, response.parsed_body)
    assert_equal "m4a", fake.calls.first[:format]
    assert_equal "en", fake.calls.first[:language]
    assert_operator fake.calls.first[:bytes], :>, 0
  end

  test "maps the upload's content type and extension to a provider format" do
    fake = FakeTranscriber.new(Result.new(text: "ok", model: "m"))
    with_transcriber(fake) do
      post "/transcriptions", params: { audio: fixture_file_upload("voice.m4a", "audio/webm") }, headers: @headers
    end
    assert_response :ok
    assert_equal "webm", fake.calls.first[:format]
  end

  test "rejects a request without audio" do
    post "/transcriptions", params: {}, headers: @headers
    assert_response :unprocessable_entity
    assert_equal "Attach a recording to transcribe.", response.parsed_body["error"]
  end

  test "rejects files that are not audio" do
    post "/transcriptions", params: { audio: fixture_file_upload("voice.m4a", "text/plain") }, headers: @headers
    assert_response :unprocessable_entity
    assert_match(/audio format/i, response.parsed_body["error"])
  end

  test "rejects recordings over the size limit" do
    with_stub(TranscriptionsController, :max_bytes, -> { 10 }) do
      post "/transcriptions", params: { audio: audio }, headers: @headers
    end
    assert_response :content_too_large
  end

  test "ignores an invalid language hint" do
    fake = FakeTranscriber.new(Result.new(text: "ok", model: "m"))
    with_transcriber(fake) do
      post "/transcriptions", params: { audio: audio, language: "english; drop" }, headers: @headers
    end
    assert_response :ok
    assert_nil fake.calls.first[:language]
  end

  test "says so when no speech was found" do
    with_transcriber(FakeTranscriber.new(Transcription::NoSpeech.new)) do
      post "/transcriptions", params: { audio: audio }, headers: @headers
    end
    assert_response :unprocessable_entity
    assert_equal "No speech found in the recording.", response.parsed_body["error"]
  end

  test "hides provider details when transcription fails" do
    failure = Transcription::ProviderError.new("upstream secret detail", status: 500)
    with_transcriber(FakeTranscriber.new(failure)) do
      post "/transcriptions", params: { audio: audio }, headers: @headers
    end
    assert_response :bad_gateway
    assert_equal "Couldn't transcribe the recording. Try again.", response.parsed_body["error"]
    refute_includes response.body, "upstream secret detail"
  end
end
