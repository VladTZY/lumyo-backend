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

  desc "Delete Pinecone vectors whose note no longer exists (DRY_RUN=1 to only report)"
  task purge_orphans: :environment do
    dry_run = ENV["DRY_RUN"].present?
    ids_by_note = PineconeHelper.each_id(prefix: "note_").group_by { |id| id[/\Anote_(\d+)_/, 1].to_i }
    orphan_note_ids = ids_by_note.keys - Note.where(id: ids_by_note.keys).pluck(:id)
    orphan_ids = ids_by_note.values_at(*orphan_note_ids).flatten

    puts "#{orphan_ids.size} orphaned vectors across #{orphan_note_ids.size} deleted notes."
    next if dry_run || orphan_ids.empty?

    PineconeHelper.delete_ids(orphan_ids)
    puts "Deleted."
  end
end
