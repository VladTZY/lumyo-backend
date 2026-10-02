class NoteEmbeddingService
  def initialize(note)
    @note = note
  end

  def call
    delete_existing_vectors
    chunks = NoteChunker.new(@note).chunks
    return if chunks.empty?

    records = chunks.map { |chunk| build_record(chunk) }
    PineconeHelper.upsert_records(records)

    # The note may have been deleted while this job was running; its removal
    # job could already have run, so clean up the vectors we just wrote.
    unless Note.exists?(@note.id)
      PineconeHelper.delete_by_filter({ "note_id" => @note.id })
      return
    end

    @note.update!(pinecone_uploaded: true, pinecone_uploaded_at: Time.current)
  end

  private

  def delete_existing_vectors
    PineconeHelper.delete_by_filter({ "note_id" => @note.id })
  rescue PineconeHelper::Error
    # Ignore delete errors — vectors may not exist yet
  end

  def build_record(chunk)
    {
      "_id"        => "note_#{@note.id}_chunk_#{chunk[:chunk_index]}",
      "text"       => chunk[:text],
      "note_id"    => @note.id,
      "user_id"    => @note.user_id,
      "chunk_index" => chunk[:chunk_index],
      "title"      => @note.title,
      "tags"       => @note.categories.pluck(:title),
      "updated_at" => @note.updated_at.iso8601
    }
  end
end
