require "test_helper"

class AppTest < ActiveSupport::TestCase
  test "accepts valid names" do
    %w[journal my-app my_app-2 A].each do |name|
      assert App.new(name:, agent: "claude").valid?, "should accept #{name.inspect}"
    end
  end

  test "rejects unsafe or ambiguous names" do
    # "--" is the app/session separator in tmux names, so it must be impossible in app names
    ["", "a b", "a;rm -rf /", "../etc", "a--b", "-lead", "trail-", "🐴"].each do |name|
      assert_not App.new(name:, agent: "claude").valid?, "should reject #{name.inspect}"
    end
  end

  test "rejects reserved names and unknown agents" do
    assert_not App.new(name: "deploy", agent: "claude").valid?
    assert_not App.new(name: "blog", agent: "copilot").valid?
  end

  test "current is the one app named by APPSMOOTHLY_APP" do
    ENV["APPSMOOTHLY_APP"] = "acme-shop"
    ENV["APPSMOOTHLY_APP_TITLE"] = "Acme Shop"
    app = App.current
    assert_equal "acme-shop", app.name
    assert_equal "Acme Shop", app.display_name
    assert_equal app, App.current # same row on the next call
  ensure
    ENV.delete("APPSMOOTHLY_APP")
    ENV.delete("APPSMOOTHLY_APP_TITLE")
  end

  test "current is nil without APPSMOOTHLY_APP" do
    ENV.delete("APPSMOOTHLY_APP")
    assert_nil App.current
  end
end

class AppTitleTest < ActiveSupport::TestCase
  test "any title becomes a safe technical name automatically" do
    app = App.new(title: "My New App!", agent: "claude")
    assert app.valid?, app.errors.full_messages.join(", ")
    assert_equal "my-new-app", app.name
    assert_equal "My New App!", app.display_name
  end

  test "title with no usable characters is rejected kindly" do
    app = App.new(title: "🐴🐴", agent: "claude")
    assert_not app.valid?
    assert_match "letters or numbers", app.errors.full_messages.first
  end
end
