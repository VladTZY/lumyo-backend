require "test_helper"

class TranscriberTest < ActiveSupport::TestCase
  # Records each call and answers from a per-model script: a String is the
  # transcript, an exception is raised.
  class FakeClient
    attr_reader :calls

    def initialize(script)
      @script = script
      @calls = []
    end

    def transcribe(audio:, format:, model:, language: nil)
      @calls << { model: model, format: format, language: language }
      outcome = @script.fetch(model)
      raise outcome if outcome.is_a?(Exception)
      outcome
    end
  end

  def retryable(status = 500) = Transcription::ProviderError.new("failed", status: status)

  test "returns the first model's transcript and which model produced it" do
    client = FakeClient.new("a" => "Hello")
    result = Transcriber.new(client: client, models: [ "a", "b" ]).call(audio: "x", format: "m4a")

    assert_equal "Hello", result.text
    assert_equal "a", result.model
    assert_equal [ "a" ], client.calls.map { _1[:model] }
  end

  test "falls back to the next model when one fails with a retryable error" do
    client = FakeClient.new("a" => retryable(400), "b" => "From b")
    result = Transcriber.new(client: client, models: [ "a", "b" ]).call(audio: "x", format: "webm")

    assert_equal "From b", result.text
    assert_equal "b", result.model
  end

  test "stops at a non-retryable error instead of trying other models" do
    client = FakeClient.new("a" => retryable(401), "b" => "never")
    assert_raises(Transcription::ProviderError) do
      Transcriber.new(client: client, models: [ "a", "b" ]).call(audio: "x", format: "m4a")
    end
    assert_equal [ "a" ], client.calls.map { _1[:model] }
  end

  test "raises the last error when every model fails" do
    client = FakeClient.new("a" => retryable(500), "b" => retryable(502))
    error = assert_raises(Transcription::ProviderError) do
      Transcriber.new(client: client, models: [ "a", "b" ]).call(audio: "x", format: "m4a")
    end
    assert_equal 502, error.status
  end

  test "raises NoSpeech when the transcript is blank" do
    client = FakeClient.new("a" => "")
    assert_raises(Transcription::NoSpeech) do
      Transcriber.new(client: client, models: [ "a" ]).call(audio: "x", format: "m4a")
    end
  end

  test "passes format and language through to the client" do
    client = FakeClient.new("a" => "Salut")
    Transcriber.new(client: client, models: [ "a" ]).call(audio: "x", format: "webm", language: "ro")
    assert_equal({ model: "a", format: "webm", language: "ro" }, client.calls.first)
  end

  test "refuses to run with no models configured" do
    assert_raises(ArgumentError) { Transcriber.new(client: FakeClient.new({}), models: []) }
  end

  test "reads the model chain from TRANSCRIPTION_MODELS, trimming blanks" do
    assert_equal [ "x/one", "y/two" ], Transcriber.models_from_env("TRANSCRIPTION_MODELS" => " x/one , ,y/two ")
  end

  test "defaults to Whisper Large V3 Turbo with Voxtral as the fallback" do
    assert_equal [ "openai/whisper-large-v3-turbo", "mistralai/voxtral-mini-transcribe" ],
      Transcriber.models_from_env({})
  end
end
