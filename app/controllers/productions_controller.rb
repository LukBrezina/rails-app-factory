class ProductionsController < ApplicationController
  # One button. On a provisioned box the app deploys to this same machine and the
  # web address already points here, so fill those in and go — no config screen.
  def deploy
    @app.update(prod_server: "localhost", prod_host: Factory.domain) if !@app.deployable? && Factory.domain
    return redirect_to root_path, alert: "This box isn't set up to go live yet." unless @app.deployable?

    Production.launch_deploy(@app)
    redirect_to session_path("deploy"), notice: "Going live — this is what's happening on the server right now."
  end
end
