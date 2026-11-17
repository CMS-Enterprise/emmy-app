require 'rails_helper'
RSpec.describe ViewHelper, type: :helper do
  describe "#switch_locale_link" do
    let(:params) { { controller: "activities/activities", action: "index" } }

    before do
      allow(helper).to receive(:t).and_return("Language Name")
      # switch_locale_link now uses path_parameters and query_parameters for better security.
      # request.params is kept for compatibility with other parts of Rails.
      full_params = ActionController::Parameters.new(params).permit!
      allow(helper.request).to receive(:params).and_return(full_params)
      allow(helper.request).to receive(:path_parameters).and_return(params.slice(:controller, :action))
      allow(helper.request).to receive(:query_parameters).and_return(full_params.except(:controller, :action))
    end

    it "generates a link with the new locale" do
      link = helper.switch_locale_link(:es)
      expect(link).to include("/es")
    end

    it "does not allow host injection via params" do
      malicious_params = params.merge(host: "evil.com")
      full_params = ActionController::Parameters.new(malicious_params).permit!
      allow(helper.request).to receive(:params).and_return(full_params)
      allow(helper.request).to receive(:path_parameters).and_return(malicious_params.slice(:controller, :action))
      allow(helper.request).to receive(:query_parameters).and_return(full_params.except(:controller, :action))

      link = helper.switch_locale_link(:es)
      expect(link).not_to include("evil.com")
      expect(link).to include("/es")
    end

    it "does not allow script_name injection" do
      malicious_params = params.merge(script_name: "//evil.example")
      full_params = ActionController::Parameters.new(malicious_params).permit!
      allow(helper.request).to receive(:params).and_return(full_params)
      allow(helper.request).to receive(:path_parameters).and_return(malicious_params.slice(:controller, :action))
      allow(helper.request).to receive(:query_parameters).and_return(full_params.except(:controller, :action))

      link = helper.switch_locale_link(:es)
      expect(link).not_to include("//evil.example")
      # It should be relative and safe
      expect(link).to include("href=\"/es/activities\"")
    end

    it "handles HashWithIndifferentAccess for params (common in controller tests)" do
      # For url_for to work in this mocked helper spec, it often needs the keys to be symbols.
      # HashWithIndifferentAccess should work, but if we slice it, we might lose something.
      hash_params = ActiveSupport::HashWithIndifferentAccess.new(params)
      allow(helper.request).to receive(:params).and_return(hash_params)
      allow(helper.request).to receive(:path_parameters).and_return(params.slice(:controller, :action))
      allow(helper.request).to receive(:query_parameters).and_return(hash_params.except(:controller, :action))

      link = helper.switch_locale_link(:es)
      expect(link).to include("/es/activities")
    end
  end
end
