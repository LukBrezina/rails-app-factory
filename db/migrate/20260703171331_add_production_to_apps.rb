class AddProductionToApps < ActiveRecord::Migration[8.1]
  def change
    add_column :apps, :prod_ip, :string
    add_column :apps, :prod_host, :string
    add_column :apps, :s3_bucket, :string
    add_column :apps, :s3_region, :string
    add_column :apps, :s3_endpoint, :string
    add_column :apps, :s3_access_key_id, :string
    add_column :apps, :s3_secret_access_key, :string
    add_column :apps, :deployed_at, :datetime
  end
end
