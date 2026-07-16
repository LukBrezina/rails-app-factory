class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  if ENV["RAILS_APP_FACTORY_PASSWORD"]
    http_basic_authenticate_with name: ENV.fetch("RAILS_APP_FACTORY_USER", "admin"),
                                 password: ENV["RAILS_APP_FACTORY_PASSWORD"]
  end

  helper_method :preview_host

  private

  def preview_host = Factory.preview_host || request.host
end
