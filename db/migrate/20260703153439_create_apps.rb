class CreateApps < ActiveRecord::Migration[8.1]
  def change
    create_table :apps do |t|
      t.string :name
      t.string :agent

      t.timestamps
    end
    add_index :apps, :name, unique: true
  end
end
