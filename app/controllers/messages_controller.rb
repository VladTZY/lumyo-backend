class MessagesController < ApplicationController
  include ActionController::Live

  before_action :set_chat

  def create
    content = params.dig(:message, :content)

    if content.blank?
      render json: { error: "Message content is required" }, status: :unprocessable_entity
      return
    end

    if @chat.available_source_note_ids.empty?
      render json: { error: "No sources selected. Please select at least one note." }, status: :unprocessable_entity
      return
    end

    if streaming_requested?
      stream_completion(content)
    else
      assistant_message = ChatCompletionService.new(@chat, content).call
      render json: assistant_message, status: :created
    end
  rescue => e
    Rails.logger.error("[MessagesController] Error: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error unless response.committed?
  end

  private

  def streaming_requested?
    request.headers["Accept"].to_s.include?("text/event-stream")
  end

  # Streams the assistant response as SSE:
  #   event: delta -> { "delta": "..." } for each streamed text chunk
  #   event: done  -> the persisted assistant message (with sources)
  #   event: error -> { "error": "..." } if generation fails
  def stream_completion(content)
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
    sse = ActionController::Live::SSE.new(response.stream)

    assistant_message = ChatCompletionService.new(@chat, content).call do |delta|
      sse.write({ delta: delta }, event: "delta")
    end
    sse.write(assistant_message.as_json, event: "done")
  rescue => e
    Rails.logger.error("[MessagesController] Streaming error: #{e.message}")
    begin
      sse.write({ error: e.message }, event: "error")
    rescue IOError
      # client disconnected
    end
  ensure
    sse&.close
  end

  def set_chat
    @chat = current_user.chats.find(params[:chat_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found" }, status: :not_found
  end
end
