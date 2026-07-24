require "test_helper"
require "tmpdir"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["APPSMOOTHLY_APP"] = "blog" # the one app this box hosts; the controller adopts it via App.current
    @app = apps(:blog)      # same row App.current finds by name
    @root = Dir.mktmpdir
    ENV["APPSMOOTHLY_PROJECTS_DIR"] = @root
    FileUtils.mkdir_p(File.join(@root, "blog", ".git")) # @app.ready?
  end

  teardown do
    FileUtils.remove_entry(@root)
    ENV.delete("APPSMOOTHLY_PROJECTS_DIR")
    ENV.delete("APPSMOOTHLY_APP")
  end

  test "create slugs the prompt into a row and hands it to claude" do
    launched = nil
    TmuxSession.stub :launch, ->(app, name, **opts) { launched = [app.name, name, opts] } do
      post sessions_path, params: { prompt: "Fix the CSV export bug" }
    end
    assert_redirected_to session_path("fix-the-csv-export-bug")
    assert Session.exists?(app: @app, name: "fix-the-csv-export-bug")
    assert_equal ["blog", "fix-the-csv-export-bug", { prompt: "Fix the CSV export bug" }], launched
  end

  test "create with a blank prompt opens a plain claude tab" do
    launched = nil
    TmuxSession.stub :launch, ->(app, name, **opts) { launched = [name, opts] } do
      post sessions_path, params: { prompt: "   " }
    end
    assert_redirected_to session_path("claude")
    assert Session.exists?(app: @app, name: "claude")
    assert_equal ["claude", { prompt: nil }], launched
  end

  test "destroy kills tmux and deletes the row" do
    Session.create!(app: @app, name: "old-work", title: "old")
    killed = nil
    TmuxSession.stub :kill, ->(_app, name) { killed = name } do
      delete session_path("old-work")
    end
    assert_equal "old-work", killed
    assert_not Session.exists?(app: @app, name: "old-work")
  end

  test "show wakes an asleep session by resuming claude" do
    Session.create!(app: @app, name: "old-work", title: "old")
    args = nil
    TmuxSession.stub :for, [] do
      TmuxSession.stub :launch, ->(_app, name, **opts) { args = [name, opts] } do
        get session_path("old-work")
      end
    end
    assert_response :success
    assert_equal ["old-work", { resume: true }], args
  end

  test "show of an unknown name never creates a workspace" do
    TmuxSession.stub :for, [] do
      TmuxSession.stub :launch, ->(*) { flunk "must not launch" } do
        get session_path("typo-name")
      end
    end
    assert_response :success
  end
end
