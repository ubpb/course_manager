class RemoveCategory < ActiveRecord::Migration[8.1]

  def down
    remove_reference :courses, :category, foreign_key: true
    remove_reference :consultings, :category, foreign_key: true
    drop_table :categories
  end

end
