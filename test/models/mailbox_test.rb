require "test_helper"
require "tmpdir"

class MailboxTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
    ENV["RAF_PROJECTS_DIR"] = @root
    @maildir = File.join(@root, ".worktrees", "blog--inbox", "tmp", "mails")
    FileUtils.mkdir_p(@maildir)
  end

  teardown do
    FileUtils.remove_entry(@root)
    ENV.delete("RAF_PROJECTS_DIR")
  end

  def write_mail(name, &block) = File.write(File.join(@maildir, name), Mail.new(&block).encoded)

  def box = Mailbox.new(App.new(name: "blog"), "inbox")

  test "lists newest first, parses headers, renders html body" do
    write_mail("20260101-000000-000000001.eml") { to "old@x.test"; from "app@x.test"; subject "Older"; body "hi" }
    write_mail("20260101-000000-000000002.eml") do
      to "you@x.test"; from "app@x.test"; subject "Welcome"
      html_part { content_type "text/html; charset=UTF-8"; body "<p>Hi <b>there</b></p>" }
    end

    msgs = box.messages
    assert_equal ["Welcome", "Older"], msgs.map(&:subject)
    assert_equal "you@x.test", msgs.first.to
    assert_includes msgs.first.body_html, "<b>there</b>"
  end

  test "find is id-based and cannot escape the maildir" do
    write_mail("20260101-000000-000000009.eml") { to "a@x.test"; from "b@x.test"; subject "Hi"; body "x" }
    assert_equal "Hi", box.find("20260101-000000-000000009").subject
    assert_nil box.find("../../../../etc/passwd")
    assert_nil box.find("nope")
  end
end
