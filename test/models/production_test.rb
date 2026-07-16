require "test_helper"

class ProductionTest < ActiveSupport::TestCase
  test "deploy config uses kamal's local registry and includes litestream when backups configured" do
    app = App.new(name: "widget", agent: "claude", prod_server: "prod-1", prod_host: "widget.example.com",
                  s3_bucket: "widget-backups", s3_region: "auto", s3_endpoint: "https://storage.googleapis.com",
                  s3_access_key_id: "GOOG1", s3_secret_access_key: "shh")
    config = YAML.safe_load(Production.deploy_yaml(app))
    assert_equal "widget", config["service"]
    assert_equal "widget", config["image"]
    assert_equal "localhost:5555", config.dig("registry", "server")
    assert_equal ["prod-1"], config["servers"]["web"]
    assert_equal "widget.example.com", config["proxy"]["host"]
    assert_equal "litestream/litestream:0.3", config.dig("accessories", "litestream", "image")
    assert_equal "https://storage.googleapis.com", config.dig("accessories", "litestream", "env", "clear", "LITESTREAM_ENDPOINT")
  end

  test "deploy config omits accessory without backups" do
    app = App.new(name: "widget", agent: "claude", prod_server: "100.64.0.7", prod_host: "widget.example.com")
    config = YAML.safe_load(Production.deploy_yaml(app))
    assert_nil config["accessories"]
    assert_nil config.dig("registry", "username")
  end
end
