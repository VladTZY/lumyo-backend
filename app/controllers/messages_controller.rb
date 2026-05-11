class MessagesController < ApplicationController
  before_action :set_chat

  def create
    content = params.dig(:message, :content)

    if content.blank?
      render json: { error: "Message content is required" }, status: :unprocessable_entity
      return
    end

    if @chat.source_note_ids.blank?
      render json: { error: "No sources selected. Please select at least one note." }, status: :unprocessable_entity
      return
    end

    assistant_message = ChatCompletionService.new(@chat, content).call
    render json: assistant_message, status: :created
  rescue => e
    Rails.logger.error("[MessagesController] Error: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:chat_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found" }, status: :not_found
  end
end
