class ProductionsController < AppScopedController
  def show
  end

  def update
    if @app.update(params.require(:app).permit(:prod_server, :prod_host))
      redirect_to production_path(@app), notice: "Saved."
    else
      flash.now[:alert] = @app.errors.full_messages.first
      render :show, status: :unprocessable_entity
    end
  end

  def deploy
    return redirect_to production_path(@app), alert: "Save the server and web address first" unless @app.deployable?

    Production.launch_deploy(@app)
    redirect_to session_path(@app, "deploy"), notice: "Going live — this is what is happening on the server right now."
  end
end
