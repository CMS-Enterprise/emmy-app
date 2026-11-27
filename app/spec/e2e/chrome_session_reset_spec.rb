require "rails_helper"

RSpec.describe "Chrome session cleanup", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }

  before do
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    page.execute_script(<<~JS)
      document.cookie = "cleanup_probe=present; path=/";
      localStorage.setItem("cleanup_probe", "present");
      sessionStorage.setItem("cleanup_probe", "present");
    JS
  end

  it "clears cookies and browser storage" do
    page.driver.reset!
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))

    expect(page.evaluate_script("document.cookie")).not_to include("cleanup_probe")
    expect(page.evaluate_script('localStorage.getItem("cleanup_probe")')).to be_nil
    expect(page.evaluate_script('sessionStorage.getItem("cleanup_probe")')).to be_nil
  end
end
