class AppScopedController < ApplicationController
  before_action :set_app

  private

  def set_app
    @app = App.find_by(name: params[:app]) or redirect_to(root_path, alert: "Unknown app")
  end
end
