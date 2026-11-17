module ViewHelper
  def switch_locale_link(locale)
    params = request.params

    # In production, request.params is an ActionController::Parameters object.
    # In RSpec controller specs, it is an ActiveSupport::HashWithIndifferentAccess.
    # ActionController::Parameters requires to_unsafe_h to bypass strong params for url_for,
    # but HashWithIndifferentAccess does not implement to_unsafe_h.
    safe_params = if params.is_a?(ActionController::Parameters)
                    params.to_unsafe_h
                  else
                    params.to_h
                  end
    safe_params = safe_params.except(:host, :port, :protocol, :script_name, :original_script_name, :anchor, :params, :trailing_slash)
    path = url_for(safe_params.merge(locale: locale, only_path: true))
    link_to t("shared.languages.#{locale}"), path, class: "usa-nav__link", data: { "turbo-prefetch": false, "action": "click->language#switchLocale", "locale": locale }
  end
end
