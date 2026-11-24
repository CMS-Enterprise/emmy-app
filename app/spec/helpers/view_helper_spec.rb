require "rails_helper"

RSpec.describe "Language switcher link", type: :request do
  def switch_locale_href
    Nokogiri::HTML(response.body).at_css("a[data-locale]")["href"]
  end

  it "adds the locale prefix when switching to a non-default locale" do
    get "/"
    expect(switch_locale_href).to eq("/es")
  end

  it "preserves query parameters, including nested ones" do
    get "/es", params: { foo: "bar", a: [ "1", "2" ] }
    expect(switch_locale_href).to eq("/en?#{{ "a" => [ "1", "2" ], "foo" => "bar" }.to_query}")
  end

  %w[host protocol port script_name].each do |option|
    it "does not treat a #{option} query param as a url_for option" do
      get "/", params: { option => "//evil.com" }
      expect(switch_locale_href).to start_with("/es?")
      expect(switch_locale_href).not_to include("://")
    end
  end
end
