class SessionsController < ApplicationController
  RESERVED_SESSION_NAMES = Session::RESERVED

  # The root landing — sign-in first (as apps#index did before we collapsed to one app).
  before_action :require_onboarding, only: :index

  # Root just drops you into a session: the first one that exists, or a fresh
  # "claude" tab if there are none yet. (JSON stays the live-state feed.)
  def index
    @sessions = @app.sessions
    respond_to do |format|
      format.json { render json: @sessions.map { |s| s.as_json(preview_host) } }
      format.html do
        first = @sessions.reject { |s| RESERVED_SESSION_NAMES.include?(s.name) }.first
        if first
          redirect_to session_path(first.name)
        elsif @app.ready?
          redirect_to(session_path(start_session))
        end
        # else: not ready yet — render the "still setting up" placeholder
      end
    end
  end

  def show
    @name = Factory.safe_name(params[:id]) or return redirect_to(sessions_path)
    @sessions = @app.sessions
    @session = @sessions.find { |s| s.name == @name } ||
               Session.new(app: @app, name: @name).tap { |s| @sessions << s }
    # Asleep (the machine restarted since) → wake it: same worktree, Claude
    # continues its conversation. Only for persisted sessions — a typo URL
    # must not create workspaces.
    TmuxSession.launch(@app, @name, resume: true) if @session.persisted? && !@session.alive? && @app.ready?
    @token = Factory.verifier.generate(@session.tmux_name, expires_in: 12.hours)
  end

  # A new tab: blank (just opens claude) or seeded with a typed task.
  def create
    return redirect_to root_path, alert: "#{@app.display_name} is still being set up — give it a minute" unless @app.ready?
    redirect_to session_path(start_session(params[:prompt].to_s.strip))
  end

  def destroy
    name = Factory.safe_name(params[:id])
    if name
      TmuxSession.kill(@app, name) # kill tmux + teardown hook + remove worktree
      Session.where(app: @app, name:).destroy_all
    end
    redirect_to root_path
  end

  private

  # Create the row + launch the tmux/worktree; returns the session name. A blank
  # prompt yields a plain "claude" tab; a task seeds claude's first message.
  def start_session(prompt = "")
    name = Session.slug_for(@app, prompt)
    Session.create!(app: @app, name:, title: prompt.presence)
    TmuxSession.launch(@app, name, prompt: prompt.presence)
    name
  end
end
