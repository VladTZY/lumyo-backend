namespace :embeddings do
  desc "Reindex all notes into Pinecone"
  task reindex_all: :environment do
    total = Note.count
    puts "Reindexing #{total} notes..."

    Note.find_each(batch_size: 50).with_index do |note, index|
      EmbedNoteJob.perform_later(note.id)
      if (index + 1) % 50 == 0 || index + 1 == total
        puts "Enqueued #{index + 1}/#{total}"
      end
    end

    puts "Done. #{total} jobs enqueued."
  end
end
