class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale

  def default_url_options
    { locale: I18n.locale }
  end

  private

  def set_locale
    requested = params[:locale].presence || session[:locale]
    requested = requested.to_s

    if I18n.available_locales.map(&:to_s).include?(requested)
      I18n.locale = requested
      session[:locale] = requested
    else
      I18n.locale = I18n.default_locale
      session[:locale] = I18n.locale.to_s
    end
  end
end
