class VersionsController < ApplicationController
  def index
    @commits = Versions.log(@app)
  end

  def rollback
    return redirect_to root_path, alert: "Put the app live once before rolling back." unless @app.deployed_at?

    if Versions.launch_rollback(@app, params[:sha])
      redirect_to session_path("rollback"), notice: "Rolling back — you can watch it happen here."
    else
      redirect_to versions_path, alert: "Couldn't roll back to that version."
    end
  end
end
