class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # The terminal grants a real shell — this box binds to loopback (see
  # config/puma.rb) and is reached only from localhost, so the network itself is
  # the boundary and no in-app login is needed.

  # This box hosts one app; every page targets it (App.current, named by APPSMOOTHLY_APP).
  before_action :set_app

  helper_method :preview_host

  private

  def set_app
    @app = App.current
    return if @app

    render plain: "This factory has no app configured. Set APPSMOOTHLY_APP to the app's name and restart.",
           status: :service_unavailable
  end

  # The landing page gates on sign-in — until Claude and gh are connected there's
  # nothing to do (used only on the root, as apps#index did before).
  def require_onboarding
    redirect_to onboarding_path unless Onboarding.new.done?
  end

  def preview_host = Factory.preview_host || request.host
end
