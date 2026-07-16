# Litestream-backed backups: restore production to a point in time, or pull the
# latest prod snapshot into a session's worktree. All work runs in visible tmux.
module Backup
  module_function

  def launch_restore(app, timestamp)
    Factory.clean_tmux!
    full = "#{app.name}--restore"
    system("tmux", "kill-session", "-t", full, err: File::NULL)
    system("tmux", "new-session", "-d", "-s", full, "-c", app.path, *env_flags(app))
    TmuxSession.style(full)
    system("tmux", "send-keys", "-t", full, "bin/restore-prod '#{timestamp}'", "Enter")
  end

  # Opens an active "data" window inside the session so the browser shows the pull live.
  def launch_pull(app, session)
    worktree = TmuxSession.worktree_path(session.tmux_name)
    system("tmux", "new-window", "-t", session.tmux_name, "-n", "data", "-c", worktree, *env_flags(app))
    system("tmux", "send-keys", "-t", "#{session.tmux_name}:data", "bin/pull-prod-data", "Enter")
  end

  def status(app)
    return nil unless app.backups_configured?
    out = nil
    Timeout.timeout(6) do
      out = IO.popen(app.litestream_env,
                     ["litestream", "generations", "s3://#{app.s3_bucket}/litestream/production"],
                     err: [:child, :out], &:read)
    end
    out.presence || "no replica found yet — deploy with backups configured first"
  rescue Errno::ENOENT
    "litestream is not installed on this machine (setup.sh installs it on the VPS)"
  rescue Timeout::Error
    "timed out talking to S3 — check credentials/endpoint"
  end

  def env_flags(app)
    app.litestream_env.merge(app.s3_env).flat_map { |key, value| ["-e", "#{key}=#{value}"] }
  end
end
