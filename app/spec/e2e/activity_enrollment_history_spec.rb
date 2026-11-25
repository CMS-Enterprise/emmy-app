require "rails_helper"

RSpec.describe "Student enrollment history", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:education) { create(:education_activity, activity_flow: flow, status: :succeeded) }

  before do
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: "Medicaid"))
    profile = Launcher::FakeNscScenarios.by_key("duplicate_enrollments_dedupe")
    identity = create(:identity, first_name: profile.first_name, last_name: profile.last_name, date_of_birth: profile.date_of_birth)
    flow.update!(identity: identity, created_at: Time.zone.local(2026, 10, 1), reporting_window_months: 3)
    Launcher::FakeNscDataFetcherService.new(education_activity: education).fetch
  end

  it "expands same-term enrolled history by default and lets the user collapse it on mobile" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit edit_activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.edit.header"))

    expect(page).to have_text("Leave of absence (as of August 3, 2026)", normalize_ws: true)
    expect(page).to have_selector("h2", text: "Enrollment #2 information")
    expect(page).to have_selector("button[aria-expanded='true']", text: "View enrollment history")
    expect(page).to have_text("Withdrawn (as of August 2, 2026)", normalize_ws: true)
    expect(page).to have_text("#{I18n.t('components.enrollment_term_table_component.status.enrolled')} (as of August 1, 2026)", normalize_ws: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    click_button "View enrollment history"
    expect(page).to have_no_text("Withdrawn (as of August 2, 2026)", normalize_ws: true)
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  it "separates enrollment and term details for each consolidated enrollment on review" do
    visit review_activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.review.title_no_school_name"))

    expect(page).to have_selector("h3", text: I18n.t("activities.summary.education.enrollment_details"), count: 2)
    expect(page).to have_selector("h3", text: I18n.t("activities.summary.education.term_details"), count: 2)
    term_tables = page.all("table", text: I18n.t("activities.summary.education.term_details"), count: 2)
    expect(term_tables.first).to have_text(I18n.t("activities.education.review.enrolled"))
    expect(term_tables[1]).to have_text("Leave of absence")
    expect(term_tables).to all(have_no_text("Harborview College"))
    expect(page).to have_text("Leave of absence")
    expect(page).to have_text("Withdrawn")
    expect(page).to have_text(I18n.t("activities.education.review.enrolled"))
  end

  context "after adding credit hours for another term" do
    let(:initial_history) do
      page.find(".usa-accordion[id^='enrollment-history-']").text
    end

    before do
      education.nsc_enrollment_terms.order(:term_begin).first.update!(enrollment_status: :less_than_half_time)
      visit edit_activities_flow_education_path(id: education)
      verify_page(page, title: I18n.t("activities.education.edit.header"))
      initial_history

      click_button I18n.t("activities.education.edit.continue")
      verify_page(page, title: I18n.t("activities.education.term_credit_hours.heading", school_name: "Harborview College"))
      fill_in I18n.t("activities.education.add_your_term.edit.credit_hours"), with: "4"
      click_button I18n.t("activities.education.term_credit_hours.continue")
      verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: "Harborview College"), skip_axe_rules: %w[heading-order])
      click_button I18n.t("activities.document_uploads.new.continue")
      click_button I18n.t("activities.document_uploads.new.empty_confirmation.continue")
      verify_page(page, title: I18n.t("activities.education.review.title_no_school_name"))
    end

    it "preserves the initial status history on final review" do
      expect(page).to have_selector("h2", text: /Enrollment #\d information/, count: 2)
      expect(page.find(".usa-accordion[id^='enrollment-history-']").text).to eq(initial_history)
      expect(page).to have_text("Leave of absence (as of August 3, 2026)", normalize_ws: true)
      expect(education.nsc_enrollment_terms.order(:term_begin).first.credit_hours).to eq(4)
    end

    context "with an unpaid-work-only invitation" do
      let(:invitation) { create(:activity_flow_invitation, unpaid_work_only: true) }

      it "preserves the initial status history on final review" do
        expect(page).to have_selector("h2", text: /Enrollment #\d information/, count: 2)
        expect(page.find(".usa-accordion[id^='enrollment-history-']").text).to eq(initial_history)
        expect(page).to have_text("Leave of absence (as of August 3, 2026)", normalize_ws: true)
        expect(education.nsc_enrollment_terms.order(:term_begin).first.credit_hours).to eq(4)
      end
    end
  end

  it "uses horizontal rules without boxes or column headings in the enrollment and history tables" do
    visit edit_activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.edit.header"))

    expect(page).to have_no_selector("table.details-table thead", visible: true)
    page.all("table.details-table", count: 5).each do |table|
      borders = page.evaluate_script(<<~JS, table)
        [getComputedStyle(arguments[0]).borderLeftWidth,
         getComputedStyle(arguments[0].querySelector("tbody td")).borderLeftWidth,
         getComputedStyle(arguments[0].querySelector("tbody tr")).borderTopWidth]
      JS
      expect(borders).to eq([ "0px", "0px", "2px" ])
    end
  end
end
