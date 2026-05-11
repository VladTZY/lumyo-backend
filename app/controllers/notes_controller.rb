class NotesController < ApplicationController
  before_action :set_note, only: [ :show, :update, :destroy ]

  def index
    render json: current_user.notes.includes(:categories, :note_summary).order(updated_at: :desc), include: [:categories, :note_summary]
  end

  def show
    render json: @note, include: [ :categories, :note_summary ]
  end

  def create
    note = current_user.notes.build(note_params)
    if note.save
      assign_categories(note, params[:category_ids])
      render json: note, include: [ :categories, :note_summary ], status: :created
    else
      render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @note.update(note_params)
      assign_categories(@note, params[:category_ids]) if params.key?(:category_ids)
      render json: @note, include: [ :categories, :note_summary ]
    else
      render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy
    head :no_content
  end

  private

  def set_note
    @note = current_user.notes.includes(:categories, :note_summary).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Note not found" }, status: :not_found
  end

  def note_params
    params.require(:note).permit(:title, :content)
  end

  # Replaces all categories on the note with the given ids (must belong to current_user)
  def assign_categories(note, category_ids)
    return unless category_ids

    ids = Array(category_ids).map(&:to_i)
    categories = current_user.categories.where(id: ids)
    note.categories = categories
  end
end
