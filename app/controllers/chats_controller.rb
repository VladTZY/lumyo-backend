class ChatsController < ApplicationController
  before_action :set_chat, only: [ :show, :update, :destroy ]

  def index
    chats = current_user.chats.order(updated_at: :desc)
    render json: chats
  end

  def show
    render json: @chat, include: :messages
  end

  def create
    chat = current_user.chats.build(chat_params)
    chat.title = "New Chat" if chat.title.blank?

    if chat.save
      render json: chat, status: :created
    else
      render json: { errors: chat.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @chat.update(chat_params)
      render json: @chat
    else
      render json: { errors: @chat.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @chat.destroy
    head :no_content
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found" }, status: :not_found
  end

  def chat_params
    params.permit(:title, source_note_ids: [])
  end
end
