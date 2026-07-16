class RenameProdIpToProdServer < ActiveRecord::Migration[8.1]
  def change
    rename_column :apps, :prod_ip, :prod_server
  end
end
