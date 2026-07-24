class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # The terminal grants a real shell, so auth fails closed: serve only with a
  # password, or an explicit APPSMOOTHLY_TRUST_NETWORK=1 opt-out (the tailscale-only
  # deploy, where the network is the boundary — see setup.sh). Never silently open.
  if ENV["RAILS_APP_FACTORY_PASSWORD"].present?
    http_basic_authenticate_with name: ENV.fetch("RAILS_APP_FACTORY_USER", "admin"),
                                 password: ENV["RAILS_APP_FACTORY_PASSWORD"]
  elsif ENV["APPSMOOTHLY_TRUST_NETWORK"].blank?
    before_action do
      render plain: "Refusing to start unauthenticated. Set RAILS_APP_FACTORY_PASSWORD to require a " \
                    "login, or APPSMOOTHLY_TRUST_NETWORK=1 if this is only reachable over a private network " \
                    "(e.g. tailscale).", status: :service_unavailable
    end
  end

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
