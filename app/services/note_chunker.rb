class NoteChunker
  MAX_CHUNK_TOKENS = 600
  TARGET_CHUNK_TOKENS = 300
  OVERLAP_TOKENS = 75
  SHORT_NOTE_THRESHOLD = 200

  def initialize(note)
    @note = note
  end

  def chunks
    return [] if @note.content.blank?

    text = @note.content
    prefix = build_prefix

    if count_tokens(text) < SHORT_NOTE_THRESHOLD
      return [{ text: "#{prefix}#{text}", chunk_index: 0, token_count: count_tokens("#{prefix}#{text}") }]
    end

    raw_chunks = split_into_chunks(text)

    raw_chunks.each_with_index.map do |chunk_text, idx|
      prefixed = "#{prefix}#{chunk_text}"
      { text: prefixed, chunk_index: idx, token_count: count_tokens(prefixed) }
    end
  end

  private

  def build_prefix
    tags = @note.categories.pluck(:title).join(", ")
    "title: #{@note.title}\ntags: #{tags}\n\n"
  end

  def count_tokens(text)
    self.class.encoder.encode(text).length
  rescue => e
    (text.length / 4.0).ceil
  end

  def self.encoder
    @encoder ||= begin
      require "tiktoken_ruby"
      Tiktoken.get_encoding("cl100k_base")
    end
  end

  def split_into_chunks(text)
    sections = split_by_headings(text)
    chunks = []

    sections.each do |section|
      if count_tokens(section) <= MAX_CHUNK_TOKENS
        chunks << section
      else
        chunks.concat(split_section(section))
      end
    end

    apply_overlap(chunks)
  end

  def split_by_headings(text)
    sections = text.split(/^(?=\#{1,3}\s)/m)
    sections.reject(&:blank?)
  end

  def split_section(section)
    blocks = extract_blocks(section)
    chunks = []
    current = +""

    blocks.each do |block|
      block_tokens = count_tokens(block)

      if block_tokens > MAX_CHUNK_TOKENS
        chunks << current.strip unless current.strip.empty?
        current = +""
        chunks.concat(split_by_sentences(block))
      elsif count_tokens(current) + block_tokens > MAX_CHUNK_TOKENS
        chunks << current.strip unless current.strip.empty?
        current = +block
      else
        current << block
      end
    end

    chunks << current.strip unless current.strip.empty?
    chunks
  end

  def extract_blocks(text)
    blocks = []
    current = +""
    lines = text.lines
    i = 0

    while i < lines.length
      line = lines[i]

      if line.match?(/\A\s*```/)
        blocks << current unless current.strip.empty?
        current = +""
        code_block = +line
        i += 1
        while i < lines.length
          code_block << lines[i]
          if lines[i].match?(/\A\s*```/)
            i += 1
            break
          end
          i += 1
        end
        blocks << code_block
        next
      end

      if line.match?(/\A\s*(?:[-*+]|\d+\.)\s/)
        blocks << current unless current.strip.empty?
        current = +""
        list_block = +line
        i += 1
        while i < lines.length && lines[i].match?(/\A\s*(?:[-*+]|\d+\.)\s/)
          list_block << lines[i]
          i += 1
        end
        blocks << list_block
        next
      end

      if line.strip.empty?
        current << line
        if current.strip.length > 0
          blocks << current
          current = +""
        end
        i += 1
        next
      end

      current << line
      i += 1
    end

    blocks << current unless current.strip.empty?
    blocks
  end

  def split_by_sentences(text)
    sentences = text.split(/(?<=\.)\s+/)
    chunks = []
    current = +""

    sentences.each do |sentence|
      if count_tokens(current) + count_tokens(sentence) > MAX_CHUNK_TOKENS && !current.strip.empty?
        chunks << current.strip
        current = +sentence
      else
        current << " " unless current.empty?
        current << sentence
      end
    end

    chunks << current.strip unless current.strip.empty?
    chunks
  end

  def apply_overlap(chunks)
    return chunks if chunks.length <= 1

    result = [chunks[0]]

    (1...chunks.length).each do |i|
      prev_text = chunks[i - 1]
      overlap = extract_tail(prev_text, OVERLAP_TOKENS)
      result << "#{overlap}\n\n#{chunks[i]}".strip
    end

    result
  end

  def extract_tail(text, target_tokens)
    paragraphs = text.split(/\n\n+/)
    tail = +""

    paragraphs.reverse_each do |para|
      candidate = para + (tail.empty? ? "" : "\n\n#{tail}")
      break if count_tokens(candidate) > target_tokens && !tail.empty?
      tail = candidate
    end

    tail
  end
end
