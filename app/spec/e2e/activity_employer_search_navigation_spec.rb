require "rails_helper"

RSpec.describe "CE employer search navigation", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:employer) do
    Aggregators::ResponseObjects::SearchResult.from_argyle(
      { "id" => "example", "name" => "Example Employer", "kind" => "employer" }
    )
  end

  before do
    allow_any_instance_of(ProviderSearchService).to receive(:search).with("Example").and_return([ employer ])
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    visit activities_flow_income_employer_search_path
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.header"))
    find('input[type="search"]').fill_in with: "Example"
    click_button I18n.t("activities.income.employer_searches.show.search")
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.search_results_header"))
  end

  it "returns to search with payroll providers and apps available" do
    click_link "Back"
    verify_page(page, title: I18n.t("activities.income.employer_searches.show.header"))

    expect(page).to have_current_path(activities_flow_income_employer_search_path)
    expect(page).to have_field("query", with: "")
    expect(page).to have_link(I18n.t("activities.income.employer_searches.show.payroll_providers"))
    expect(page).to have_link(I18n.t("activities.income.employer_searches.show.app_based_providers"))
  end
end
