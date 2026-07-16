class AddTitleToApps < ActiveRecord::Migration[8.1]
  def change
    add_column :apps, :title, :string
    reversible do |dir|
      dir.up { execute "UPDATE apps SET title = name" }
    end
  end
end
