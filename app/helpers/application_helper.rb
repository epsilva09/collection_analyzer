module ApplicationHelper
  def locale_switch_url(locale)
    base_params = request.query_parameters.symbolize_keys.except(:locale)
    path_params = request.path_parameters.symbolize_keys.slice(:controller, :action, :id)

    url_for(path_params.merge(base_params).merge(locale: locale))
  end
end
