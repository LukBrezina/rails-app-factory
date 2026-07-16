class SessionsController < AppScopedController
  RESERVED_SESSION_NAMES = %w[setup deploy restore].freeze

  def index
    @sessions = @app.sessions
    respond_to do |format|
      format.html
      format.json { render json: @sessions.map { |s| s.as_json(preview_host) } }
    end
  end

  def show
    @name = Factory.safe_name(params[:id]) or return redirect_to(sessions_path(@app))
    @sessions = @app.sessions
    @session = @sessions.find { |s| s.name == @name } ||
               TmuxSession.new(app: @app, name: @name).tap { |s| @sessions << s }
    @token = Factory.verifier.generate(@session.tmux_name, expires_in: 12.hours)
  end

  def create
    name = Factory.safe_name(params[:name].to_s.parameterize) # "Add user login" → "add-user-login"
    return redirect_to sessions_path(@app), alert: "Give it a name with a few letters or numbers" unless name
    return redirect_to sessions_path(@app), alert: "That name is reserved — pick another one" if RESERVED_SESSION_NAMES.include?(name)
    return redirect_to sessions_path(@app), alert: "#{@app.display_name} is still being built — give it a minute" unless @app.ready?

    TmuxSession.launch(@app, name)
    redirect_to session_path(@app, name)
  end

  def destroy
    name = Factory.safe_name(params[:id])
    TmuxSession.kill(@app, name) if name
    redirect_to sessions_path(@app)
  end
end
