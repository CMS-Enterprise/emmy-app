module ViewHelper
  def switch_locale_link(locale)
    params = request.params
    raw_params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params
    safe_params = raw_params.except(:host, :port, :protocol, :script_name, :original_script_name, :anchor, :params, :trailing_slash)
    path = url_for(safe_params.merge(locale: locale, only_path: true))
    link_to t("shared.languages.#{locale}"), path, class: "usa-nav__link", data: { "turbo-prefetch": false, "action": "click->language#switchLocale", "locale": locale }
  end
end
