class CreateNoteCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :note_categories do |t|
      t.references :note, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
    add_index :note_categories, [ :note_id, :category_id ], unique: true
  end
end
