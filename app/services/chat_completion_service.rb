class ChatCompletionService
  def initialize(chat, user_message)
    @chat = chat
    @user_message = user_message
  end

  # Yields response text deltas as they stream in when a block is given.
  def call(&on_delta)
    raise "No sources selected" if @chat.source_note_ids.blank?

    # 1. Search Pinecone for relevant chunks
    context_results = search_sources

    # 2. Snapshot history, then save the user message
    history = @chat.messages.order(:created_at).last(10)
    @chat.messages.create!(role: "user", content: @user_message)

    # 3. Build prompt and call LLM
    response = generate_response(context_results, history, &on_delta)

    # 4. Save and return assistant message with sources
    sources = build_sources(context_results)
    @chat.messages.create!(role: "assistant", content: response, sources: sources)
  end

  private

  def search_sources
    filter = {
      "note_id" => { "$in" => @chat.source_note_ids },
      "user_id" => @chat.user_id
    }

    result = PineconeHelper.search(@user_message, top_k: 5, filter: filter)
    result&.dig("result", "hits") || []
  rescue PineconeHelper::Error => e
    Rails.logger.error("[ChatCompletionService] Pinecone search failed: #{e.message}")
    []
  end

  def generate_response(context_results, history, &on_delta)
    context_text = context_results.map { |hit|
      fields = hit["fields"] || {}
      title = fields["title"] || "Untitled"
      text = fields["text"] || ""
      "[From: #{title}]\n#{text}"
    }.join("\n\n---\n\n")

    chat = RubyLLM.chat(model: "google/gemini-3-flash-preview")
    chat.with_instructions(system_prompt(context_text))

    history.each do |msg|
      chat.add_message(role: msg.role == "assistant" ? :assistant : :user, content: msg.content)
    end

    result = if on_delta
      chat.ask(@user_message) { |chunk| on_delta.call(chunk.content) if chunk.content.present? }
    else
      chat.ask(@user_message)
    end
    result.content
  end

  def build_sources(context_results)
    context_results.filter_map { |hit|
      fields = hit["fields"] || {}
      note_id = fields["note_id"]
      next unless note_id

      {
        "note_id" => note_id,
        "title" => fields["title"] || "Untitled",
        "chunk_text" => (fields["text"] || "").truncate(200)
      }
    }.uniq { |s| s["note_id"] }
  end

  def system_prompt(context)
    <<~PROMPT
      You are the user's second brain — a personal knowledge assistant that helps them think, recall, and connect ideas from their own notes.

      CONTEXT FROM USER'S NOTES:
      #{context}

      RULES:
      - Answer based on the provided context from the user's notes
      - If the context contains the answer, respond clearly and cite which note(s) you drew from
      - If the context doesn't contain enough information, say so honestly — don't make things up
      - Connect ideas across different notes when relevant
      - Be concise but thorough — match the depth of the question
      - Use the same tone and terminology found in the user's notes
      - When quoting or referencing specific content, mention the note title
    PROMPT
  end
end
