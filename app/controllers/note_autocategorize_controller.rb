class NoteAutocategorizeController < ApplicationController
  before_action :set_note

  def create
    categories = current_user.categories
    if categories.empty?
      return render json: { error: "No categories exist. Create a category first." }, status: :unprocessable_entity
    end

    category_list = categories.map { |c| "#{c.id}: #{c.title}" }.join("\n")

    chat = RubyLLM.chat(model: "anthropic/claude-3-haiku")
    result = chat.ask(<<~PROMPT)
      You are a note categorization assistant. Given a note and a list of categories, respond with ONLY the numeric ID of the single best-matching category. No explanation, no text, just the number.

      Categories:
      #{category_list}

      Note title: #{@note.title}

      Note content:
      #{@note.content}
    PROMPT

    chosen_id = result.content.strip.to_i
    category = categories.find { |c| c.id == chosen_id }

    unless category
      return render json: { error: "Could not determine a matching category." }, status: :unprocessable_entity
    end

    @note.categories = [ category ]
    render json: @note, include: [ :categories, :note_summary ]
  end

  private

  def set_note
    @note = current_user.notes.find(params[:note_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Note not found" }, status: :not_found
  end
end
