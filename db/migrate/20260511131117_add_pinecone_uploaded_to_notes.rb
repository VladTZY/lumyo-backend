class AddPineconeUploadedToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :pinecone_uploaded, :boolean, default: false, null: false
    add_column :notes, :pinecone_uploaded_at, :datetime
  end
end
