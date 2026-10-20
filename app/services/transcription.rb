module Transcription
  # A transcription provider call failed. `status` is the HTTP status, or nil
  # for network errors. Retryable errors can succeed with another model (a 400
  # often means that model rejects the audio format); auth and billing
  # failures would fail the same way for every model.
  class ProviderError < StandardError
    NOT_RETRYABLE = [ 401, 402, 403 ].freeze

    attr_reader :status

    def initialize(message = "Transcription failed", status: nil)
      super(message)
      @status = status
    end

    def retryable?
      !NOT_RETRYABLE.include?(status)
    end
  end

  # The provider answered, but the recording held no recognisable speech.
  class NoSpeech < StandardError
    def initialize(message = "No speech found in the recording")
      super
    end
  end
end
