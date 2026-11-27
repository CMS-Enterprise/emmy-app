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

  it "clears cookies and both storage types, including repeated resets from a blank page" do
    page.driver.reset!
    page.driver.reset!
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))

    expect(page.evaluate_script("document.cookie")).not_to include("cleanup_probe")
    expect(page.evaluate_script('localStorage.getItem("cleanup_probe")')).to be_nil
    expect(page.evaluate_script('sessionStorage.getItem("cleanup_probe")')).to be_nil
  end

  it "closes extra windows and returns the original window to a blank page" do
    original_window = page.current_window
    page.open_new_window

    page.driver.reset!

    expect(page.windows).to eq([ original_window ])
    expect(page.current_url).to eq("about:blank")
  end
end
