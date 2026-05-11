class CreateChatsAndMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chats do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.jsonb :source_note_ids, default: []
      t.timestamps
    end

    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.jsonb :sources, default: []
      t.timestamps
    end
  end
end
