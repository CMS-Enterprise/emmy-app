module ViewHelper
  def switch_locale_link(locale)
    path = url_for(request.params.to_unsafe_h.merge(locale: locale, only_path: true))
    link_to t("shared.languages.#{locale}"), path, class: "usa-nav__link", data: { "turbo-prefetch": false, "action": "click->language#switchLocale", "locale": locale }
  end
end
