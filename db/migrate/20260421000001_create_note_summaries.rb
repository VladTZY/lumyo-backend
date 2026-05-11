class CreateNoteSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :note_summaries do |t|
      t.references :note, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "pending"
      t.text :content
      t.text :error_message

      t.timestamps
    end
  end
end
