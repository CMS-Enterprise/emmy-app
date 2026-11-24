module ViewHelper
  def switch_locale_link(locale)
    # To satisfy Brakeman and maintain security, we avoid rebuilding the URL from parameters.
    # Instead, we keep the same base path and just update the locale part of the path.
    # We also preserve the query string if present, but since we use request.path,
    # we don't have to worry about host injection via request.params.

    path = url_for(
      request.path_parameters.merge(
        locale: locale,
        only_path: true,
        params: request.query_parameters.except("locale")
      )
    )

    link_to t("shared.languages.#{locale}"), path, class: "usa-nav__link", data: { "turbo-prefetch": false, "action": "click->language#switchLocale", "locale": locale }
  end
end
