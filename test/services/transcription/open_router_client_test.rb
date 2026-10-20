require "test_helper"

class Transcription::OpenRouterClientTest < ActiveSupport::TestCase
  URL = "https://openrouter.ai/api/v1/audio/transcriptions".freeze

  def client_with(&handler)
    stubs = Faraday::Adapter::Test::Stubs.new { |stub| stub.post(URL, &handler) }
    connection = Faraday.new { |f| f.adapter :test, stubs }
    Transcription::OpenRouterClient.new(api_key: "test-key", connection: connection)
  end

  test "posts base64 audio as JSON with the model and denies data collection" do
    seen = nil
    client = client_with do |env|
      seen = env
      [ 200, { "Content-Type" => "application/json" }, { text: "Hello there" }.to_json ]
    end

    text = client.transcribe(audio: "RIFFbytes", format: "m4a", model: "openai/whisper-large-v3-turbo")

    assert_equal "Hello there", text
    body = JSON.parse(seen.request_body)
    assert_equal "openai/whisper-large-v3-turbo", body["model"]
    assert_equal({ "data" => Base64.strict_encode64("RIFFbytes"), "format" => "m4a" }, body["input_audio"])
    assert_equal({ "data_collection" => "deny" }, body["provider"])
    assert_equal "Bearer test-key", seen.request_headers["Authorization"]
    assert_equal "application/json", seen.request_headers["Content-Type"]
  end

  test "sends a language hint only when one is given" do
    bodies = []
    client = client_with do |env|
      bodies << JSON.parse(env.request_body)
      [ 200, {}, { text: "Salut" }.to_json ]
    end

    client.transcribe(audio: "x", format: "webm", model: "m")
    client.transcribe(audio: "x", format: "webm", model: "m", language: "ro")

    refute bodies[0].key?("language")
    assert_equal "ro", bodies[1]["language"]
  end

  test "strips surrounding whitespace from the transcript" do
    client = client_with { [ 200, {}, { text: "  Remember the lab.\n" }.to_json ] }
    assert_equal "Remember the lab.", client.transcribe(audio: "x", format: "m4a", model: "m")
  end

  test "raises a ProviderError carrying the status on a non-2xx response" do
    client = client_with { [ 400, {}, { error: { message: "Provider returned 400" } }.to_json ] }

    error = assert_raises(Transcription::ProviderError) do
      client.transcribe(audio: "x", format: "m4a", model: "m")
    end
    assert_equal 400, error.status
    assert error.retryable?, "a 400 can mean this model rejects the format, so another model may work"
  end

  test "treats auth and billing failures as not worth retrying with another model" do
    [ 401, 402, 403 ].each do |status|
      client = client_with { [ status, {}, "{}" ] }
      error = assert_raises(Transcription::ProviderError) do
        client.transcribe(audio: "x", format: "m4a", model: "m")
      end
      refute error.retryable?, "status #{status} should not fall back"
    end
  end

  test "raises a retryable ProviderError when the response has no text" do
    client = client_with { [ 200, {}, { usage: {} }.to_json ] }
    error = assert_raises(Transcription::ProviderError) do
      client.transcribe(audio: "x", format: "m4a", model: "m")
    end
    assert error.retryable?
  end

  test "wraps network failures in a retryable ProviderError" do
    stubs = Faraday::Adapter::Test::Stubs.new { |stub| stub.post(URL) { raise Faraday::TimeoutError } }
    connection = Faraday.new { |f| f.adapter :test, stubs }
    client = Transcription::OpenRouterClient.new(api_key: "k", connection: connection)

    error = assert_raises(Transcription::ProviderError) do
      client.transcribe(audio: "x", format: "m4a", model: "m")
    end
    assert error.retryable?
    assert_nil error.status
  end

  test "never puts the API key in the error message" do
    client = client_with { [ 500, {}, "upstream exploded" ] }
    error = assert_raises(Transcription::ProviderError) do
      client.transcribe(audio: "x", format: "m4a", model: "m")
    end
    refute_includes error.message, "test-key"
  end
end
