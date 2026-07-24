require "shellwords"
require "time"

# The "Versions" panel: list the app's git commits and roll production back to
# one of them — code AND data together, in a visible "<app>--rollback" tmux
# session. A provisioned box already has everything this needs (kamal to deploy,
# litestream backups to rewind the data); the user just has Claude commit often.
module Versions
  module_function

  SEP = "\x1f" # unit separator — safe inside commit subjects

  def log(app, limit: 50)
    return [] unless app.ready?
    fmt = %w[%H %h %s %cI].join("%x1f")
    `git -C #{app.path.shellescape} log -n #{limit} --format=#{fmt.shellescape} 2>/dev/null`
      .each_line.filter_map { |line|
        sha, short, subject, iso = line.chomp.split(SEP)
        { sha:, short:, subject:, at: (Time.iso8601(iso) rescue nil) } if sha
      }
  end

  # Roll code back to `sha`, then (when backups are on) rewind the live data to
  # that commit's moment. The reset is instant; the deploy + restore stream into
  # the tmux session the browser attaches to.
  def launch_rollback(app, sha)
    sha = sha.to_s[/\A[0-9a-f]{7,40}\z/] or return false
    ts = commit_time(app, sha)
    system("git", "-C", app.path, "reset", "--hard", sha) or return false
    # ponytail: reset --hard rewinds the deploy branch; superseded commits stay
    # reachable via reflog and any raf/<session> branches.
    Production.write_config(app) # commits deploy.yml/.kamal onto the rolled-back base
    Factory.clean_tmux!
    full = "#{app.name}--rollback"
    system("tmux", "kill-session", "-t", full, err: File::NULL)
    system("tmux", "new-session", "-d", "-s", full, "-c", app.path, *env_flags(app))
    TmuxSession.style(full)
    cmd = "bin/kamal deploy"
    cmd += " && bin/restore-prod '#{ts}'" if app.backups_configured? && ts
    system("tmux", "send-keys", "-t", full, cmd, "Enter")
    app.update!(deployed_at: Time.current)
    true
  end

  def commit_time(app, sha)
    iso = `git -C #{app.path.shellescape} show -s --format=%cI #{sha.shellescape} 2>/dev/null`.chomp
    Time.iso8601(iso).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  rescue StandardError
    nil
  end

  # deploy needs S3 + SMTP; the restore step needs LITESTREAM_* — pass them all.
  def env_flags(app)
    env = app.s3_env.merge(app.litestream_env)
    env["SMTP_PASSWORD"] = ENV["APPSMOOTHLY_SMTP_PASSWORD"].to_s if Production.smtp_clear_env.any?
    env.flat_map { |k, v| ["-e", "#{k}=#{v}"] }
  end
end
