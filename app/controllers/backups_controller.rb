class BackupsController < AppScopedController
  def show
    @status = Backup.status(@app)
    @sessions = @app.sessions.reject { |s| SessionsController::RESERVED_SESSION_NAMES.include?(s.name) }
  end

  def update
    @app.update!(params.require(:app).permit(:s3_bucket, :s3_region, :s3_endpoint, :s3_access_key_id, :s3_secret_access_key))
    redirect_to backups_path(@app), notice: "Saved — backups start the next time you put the app live."
  end

  def restore
    return redirect_to backups_path(@app), alert: "Set up backups first" unless @app.backups_configured?
    timestamp = Time.zone.parse(params[:timestamp].to_s)&.utc&.strftime("%Y-%m-%dT%H:%M:%SZ")
    return redirect_to backups_path(@app), alert: "Pick a valid date and time" unless timestamp

    Backup.launch_restore(@app, timestamp)
    redirect_to session_path(@app, "restore"), notice: "Rewinding your live app to #{timestamp} — you can watch it happen here."
  end

  def pull
    return redirect_to backups_path(@app), alert: "Set up backups first" unless @app.backups_configured?
    name = Factory.safe_name(params[:id])
    session = @app.sessions.find { |s| s.name == name }
    return redirect_to backups_path(@app), alert: "Session not found" unless session

    Backup.launch_pull(@app, session)
    redirect_to session_path(@app, session.name), notice: "Copying live data into this workspace — it appears in the 'data' window."
  end
end
