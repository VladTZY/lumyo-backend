class ChatCompletionService
  # Final line the model appends to declare which notes it actually used,
  # e.g. "[SOURCES: 12, 15]" or "[SOURCES: none]".
  SOURCE_MARKER_START = "[SOURCES:".freeze
  SOURCE_MARKER_RE = /\s*\[SOURCES:\s*([^\]]*)\]\s*\z/

  def initialize(chat, user_message)
    @chat = chat
    @user_message = user_message
  end

  # Yields response text deltas as they stream in when a block is given.
  def call(&on_delta)
    # Deleted notes can linger in source_note_ids; never search for them.
    @source_note_ids = @chat.available_source_note_ids
    raise "No sources selected" if @source_note_ids.empty?

    # 1. Search Pinecone for relevant chunks
    context_results = search_sources

    # 2. Snapshot history, then save the user message
    history = @chat.messages.order(:created_at).last(10)
    @chat.messages.create!(role: "user", content: @user_message)

    # 3. Build prompt and call LLM
    response = generate_response(context_results, history, &on_delta)

    # 4. Keep only the sources the model declared it used, strip the marker
    content, used_note_ids = extract_used_sources(response)
    sources = build_sources(context_results, used_note_ids)
    @chat.messages.create!(role: "assistant", content: content, sources: sources)
  end

  private

  def search_sources
    filter = {
      "note_id" => { "$in" => @source_note_ids },
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
      note_id = fields["note_id"]
      text = fields["text"] || ""
      "[NOTE #{note_id}: #{title}]\n#{text}"
    }.join("\n\n---\n\n")

    chat = RubyLLM.chat(model: "google/gemini-3-flash-preview")
    chat.with_instructions(system_prompt(context_text))

    history.each do |msg|
      chat.add_message(role: msg.role == "assistant" ? :assistant : :user, content: msg.content)
    end

    result = if on_delta
      stream_holding_back_marker(chat, &on_delta)
    else
      chat.ask(@user_message)
    end
    result.content
  end

  # Streams deltas to the client while holding back anything that could be
  # the start of the trailing [SOURCES: ...] marker, so it never appears
  # in the visible stream.
  def stream_holding_back_marker(chat, &on_delta)
    buffer = +""
    flushed = 0

    result = chat.ask(@user_message) do |chunk|
      next if chunk.content.blank?

      buffer << chunk.content
      safe = safe_flush_length(buffer)
      if safe > flushed
        on_delta.call(buffer[flushed...safe])
        flushed = safe
      end
    end

    # Flush whatever held-back tail is not part of the marker
    clean, _ids = extract_used_sources(buffer)
    on_delta.call(clean[flushed..]) if clean.length > flushed

    result
  end

  # Everything before a (possibly partial) marker at the tail is safe to emit.
  # Trailing whitespace is held back too, so stripping the marker never leaves
  # dangling blank lines at the end of the stream.
  def safe_flush_length(buffer)
    safe = buffer.index(SOURCE_MARKER_START)

    unless safe
      safe = buffer.length
      max_partial = [ SOURCE_MARKER_START.length - 1, buffer.length ].min
      max_partial.downto(1) do |n|
        if buffer.end_with?(SOURCE_MARKER_START[0, n])
          safe = buffer.length - n
          break
        end
      end
    end

    safe -= 1 while safe > 0 && buffer[safe - 1].match?(/\s/)
    safe
  end

  # Returns [content without the marker, declared note ids or nil if absent].
  def extract_used_sources(text)
    ids = nil
    content = text.sub(SOURCE_MARKER_RE) do
      ids = Regexp.last_match(1).scan(/\d+/).map(&:to_i)
      ""
    end
    [ content.rstrip, ids ]
  end

  def build_sources(context_results, used_note_ids)
    retrieved = context_results.filter_map { |hit|
      fields = hit["fields"] || {}
      note_id = fields["note_id"]
      next unless note_id

      {
        "note_id" => note_id,
        "title" => fields["title"] || "Untitled",
        "chunk_text" => (fields["text"] || "").truncate(200)
      }
    }.uniq { |s| s["note_id"] }

    # Model didn't declare sources — fall back to everything retrieved
    return retrieved if used_note_ids.nil?

    retrieved.select { |s| used_note_ids.include?(s["note_id"].to_i) }
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
      - When quoting or referencing specific content, mention the note title (never the note id)
      - End your response with exactly one final line declaring which notes you actually drew on, using their ids from the context headers: [SOURCES: 12, 15] — or [SOURCES: none] if you used none of them. This line is mandatory and must not be mentioned anywhere else in your answer.
    PROMPT
  end
end
