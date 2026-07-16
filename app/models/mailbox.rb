# Reads the "test inbox" a dev app writes to its worktree's tmp/mails (see the
# RafMailbox delivery method that bin/create-app installs). Like the rest of the
# factory, the filesystem is the source of truth — nothing here touches the DB.
class Mailbox
  SUBDIR = "tmp/mails"

  def initialize(app, session)
    @dir = File.join(TmuxSession.worktree_path("#{app.name}--#{session}"), SUBDIR)
  end

  def messages = files.map { |path| Message.new(path) }

  # id-based lookup that only ever matches a real file in the maildir, so a
  # crafted id can't traverse out (we never build a path from user input).
  def find(id)
    path = files.find { |f| File.basename(f, ".eml") == id }
    Message.new(path) if path
  end

  # Re-deliver a captured email to a real address via the factory's SMTP relay.
  def forward(id, to)
    message = find(id) or return false
    m = message.mail
    m.to = to
    m.cc = m.bcc = nil # only the typed address should receive it
    m.from = ENV["RAF_SMTP_FROM"] if ENV["RAF_SMTP_FROM"].present?
    m.delivery_method :smtp, self.class.smtp_settings
    m.deliver!
    true
  end

  class << self
    def smtp_configured? = ENV["RAF_SMTP_ADDRESS"].present?

    def smtp_settings
      { address: ENV["RAF_SMTP_ADDRESS"], port: (ENV["RAF_SMTP_PORT"].presence || 587).to_i,
        user_name: ENV["RAF_SMTP_USER_NAME"].presence, password: ENV["RAF_SMTP_PASSWORD"].presence,
        domain: ENV["RAF_SMTP_DOMAIN"].presence, authentication: :plain, enable_starttls_auto: true }.compact
    end
  end

  private

  def files = Dir.glob(File.join(@dir, "*.eml")).sort.reverse # newest first (timestamped names)

  # One captured email; parses lazily with the `mail` gem (a Rails dependency).
  Message = Struct.new(:path) do
    def id = File.basename(path, ".eml")
    def mail = @mail ||= Mail.read(path)
    def subject = mail.subject.presence || "(no subject)"
    def from = Array(mail.from).join(", ")
    def to = Array(mail.to).join(", ")
    def date = mail.date&.to_time || File.mtime(path)

    # Final HTML for a sandboxed <iframe srcdoc>. Returns a plain (unsafe) String
    # on purpose: the view lets Rails escape it into the srcdoc attribute, which
    # the browser then decodes back into the framed document.
    def body_html
      if mail.html_part
        mail.html_part.decoded
      elsif mail.mime_type == "text/html"
        mail.decoded
      else
        text = mail.text_part&.decoded || mail.decoded
        %(<pre style="white-space:pre-wrap;font:14px/1.5 system-ui,sans-serif;margin:1rem;color:#2f2b23">) +
          ERB::Util.html_escape(text) + "</pre>"
      end
    end
  end
end
