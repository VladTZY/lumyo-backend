class NoteSummariesController < ApplicationController
  before_action :set_note

  def show
    summary = @note.note_summary
    return render json: { error: "No summary found" }, status: :not_found unless summary

    render json: summary
  end

  def create
    summary = @note.note_summary || @note.build_note_summary
    summary.assign_attributes(status: "pending", content: nil, error_message: nil)
    summary.save!

    GenerateNoteSummaryJob.perform_later(summary.id)

    render json: summary, status: :accepted
  end

  private

  def set_note
    @note = current_user.notes.find(params[:note_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Note not found" }, status: :not_found
  end
end
