class AutocategorizeAllController < ApplicationController
  def create
    categories = current_user.categories
    if categories.empty?
      return render json: { error: "No categories exist. Create a category first." }, status: :unprocessable_entity
    end

    uncategorized = current_user.notes
      .left_joins(:note_categories)
      .where(note_categories: { id: nil })

    if uncategorized.empty?
      return render json: { categorized: 0 }
    end

    category_list = categories.map { |c| "#{c.id}: #{c.title}" }.join("\n")
    notes_list = uncategorized.map { |n| "Note #{n.id}: [#{n.title}] #{n.content.to_s.truncate(200)}" }.join("\n\n")

    chat = RubyLLM.chat(model: "anthropic/claude-3-haiku")
    result = chat.ask(<<~PROMPT)
      You are a note categorization assistant. Given a list of notes and a list of categories, assign each note to the single best-matching category.

      Respond with ONLY lines in the format: note_id:category_id
      No explanation, no text, just the mappings, one per line.

      Categories:
      #{category_list}

      Notes:
      #{notes_list}
    PROMPT

    categorized = 0
    category_ids = categories.map(&:id).to_set

    result.content.strip.lines.each do |line|
      parts = line.strip.split(":")
      next unless parts.length == 2

      note_id = parts[0].strip.to_i
      cat_id = parts[1].strip.to_i

      note = uncategorized.find { |n| n.id == note_id }
      next unless note && category_ids.include?(cat_id)

      note.categories = [ categories.find { |c| c.id == cat_id } ]
      categorized += 1
    end

    render json: { categorized: categorized }
  end
end
