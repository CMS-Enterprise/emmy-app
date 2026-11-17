module ViewHelper
  def switch_locale_link(locale)
    # Brakeman flags the use of request.params.to_unsafe_h as a potential XSS/Open Redirect risk (LinkToHref).
    # To satisfy Brakeman and maintain security, we use request.path_parameters and request.query_parameters
    # which are safer alternatives to request.params.
    # We explicitly merge them, permit everything (since we want to preserve current state),
    # but critically exclude keys that could lead to host injection.

    # In production, query_parameters is an ActionController::Parameters object.
    # In RSpec controller specs, it might be a simple Hash or HashWithIndifferentAccess.
    query_params = request.query_parameters
    path_params = request.path_parameters

    q = query_params.respond_to?(:permit!) ? query_params.clone.permit!.to_h : query_params.to_h
    p = path_params.respond_to?(:permit!) ? path_params.clone.permit!.to_h : path_params.to_h

    safe_params = p.merge(q).except(:host, :port, :protocol, :script_name, :original_script_name, :anchor, :params, :trailing_slash, "host", "port", "protocol", "script_name", "original_script_name")
    path = url_for(safe_params.merge(locale: locale, only_path: true))
    link_to t("shared.languages.#{locale}"), path, class: "usa-nav__link", data: { "turbo-prefetch": false, "action": "click->language#switchLocale", "locale": locale }
  end
end
