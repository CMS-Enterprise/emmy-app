require "rails_helper"

RSpec.describe "NSC enrollment statuses", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:flow) { invitation.activity_flows.order(:created_at).last }
  let(:education) { create(:education_activity, activity_flow: flow) }
  let(:enrollment_codes) { %w[F Q H L Y A W S G D] }
  let(:other_school) { nil }
  let(:other_term_end) { nil }

  before do
    visit activities_flow_start_path(token: invitation.auth_token)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    flow.update!(identity: create(:identity, :nsc_lynette), created_at: Date.new(2024, 7, 15), reporting_window_months: 6)
    nsc_stub_token_request
    nsc_stub_request_education_search_response("lynette") do |response|
      enrollment = response.fetch("enrollmentDetails").first
      template = enrollment.fetch("enrollmentData").first
      if other_school || other_term_end
        additional = enrollment.deep_dup
        additional["officialSchoolName"] = other_school if other_school
        data = template.merge("enrollmentStatus" => "Y", "schoolCertifiedOnDate" => "2024-06-15")
        data["termEndDate"] = other_term_end if other_term_end
        additional["enrollmentData"] = [ data ]
        response["enrollmentDetails"] << additional
      end
      enrollment["enrollmentData"] = enrollment_codes.map do |code|
        template.merge("enrollmentStatus" => code,
          "schoolCertifiedOnDate" => code == "Y" || code == "L" ? "2024-06-01" : "2024-07-01")
      end
    end
    NscDataFetcherService.new(education_activity: education, environment: :test).fetch
    visit activities_flow_education_path(id: education)
    verify_page(page, title: I18n.t("activities.education.edit.header"), wait: 10)
  end

  it "expands previous enrollment and combines school and Clearinghouse withdrawals" do
    expect(page).to have_selector("button[aria-expanded='true']", text: I18n.t("activities.education.edit.enrollment_history", count: 8))

    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.leave_of_absence"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.graduated"))
    expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.deceased"))
    expect(page).to have_selector("td", text: I18n.t("components.enrollment_term_table_component.status.withdrawn"), count: 1)
    expect(education.nsc_enrollment_terms.count).to eq(9)
  end

  def continue_without_supplemental_details
    expect(education.reload).to be_validated
    click_button I18n.t("activities.education.edit.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(page).to have_current_path(activities_flow_root_path)
    expect(education.reload).not_to be_draft
  end

  context "when the latest status is Clearinghouse withdrawal" do
    let(:enrollment_codes) { %w[Y S] }

    it "lands on Enrollment Details with the same-term enrolled history expanded" do
      expect(page).to have_selector("button[aria-expanded='true']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
      expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
      continue_without_supplemental_details
    end

    context "without previous enrolled history" do
      let(:enrollment_codes) { %w[L S] }

      it "lands on Enrollment Details with history collapsed" do
        expect(page).to have_selector("button[aria-expanded='false']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
        expect(page).to have_no_text(I18n.t("components.enrollment_term_table_component.status.less_than_half_time"))
        continue_without_supplemental_details
      end
    end
  end

  context "when the latest status is school withdrawal" do
    let(:enrollment_codes) { %w[Y W] }

    it "lands on Enrollment Details with the same-term enrolled history expanded" do
      expect(page).to have_selector("button[aria-expanded='true']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
      expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
      continue_without_supplemental_details
    end

    context "without previous enrolled history" do
      let(:enrollment_codes) { %w[L W] }

      it "lands on Enrollment Details with history collapsed" do
        expect(page).to have_selector("button[aria-expanded='false']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
        expect(page).to have_no_text(I18n.t("components.enrollment_term_table_component.status.less_than_half_time"))
        continue_without_supplemental_details
      end
    end
  end

  context "when the latest status is leave of absence" do
    let(:enrollment_codes) { %w[Y A] }

    it "lands on Enrollment Details with the same-term enrolled history expanded" do
      expect(page).to have_selector("button[aria-expanded='true']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
      expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
      continue_without_supplemental_details
    end

    context "without previous enrolled history" do
      let(:enrollment_codes) { %w[L A] }

      it "lands on Enrollment Details with history collapsed" do
        expect(page).to have_selector("button[aria-expanded='false']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
        expect(page).to have_no_text(I18n.t("components.enrollment_term_table_component.status.less_than_half_time"))
        continue_without_supplemental_details
      end
    end
  end

  context "when the latest status is graduation" do
    let(:enrollment_codes) { %w[Y G] }

    it "lands on Enrollment Details with the same-term enrolled history expanded" do
      expect(page).to have_selector("button[aria-expanded='true']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
      expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
      continue_without_supplemental_details
    end

    context "without previous enrolled history" do
      let(:enrollment_codes) { %w[L G] }

      it "lands on Enrollment Details with history collapsed" do
        expect(page).to have_selector("button[aria-expanded='false']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
        expect(page).to have_no_text(I18n.t("components.enrollment_term_table_component.status.less_than_half_time"))
        continue_without_supplemental_details
      end
    end
  end

  context "when the latest status is deceased" do
    let(:enrollment_codes) { %w[Y D] }

    it "lands on Enrollment Details with the same-term enrolled history expanded" do
      expect(page).to have_selector("button[aria-expanded='true']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
      expect(page).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
      continue_without_supplemental_details
    end

    context "without previous enrolled history" do
      let(:enrollment_codes) { %w[L D] }

      it "lands on Enrollment Details with history collapsed" do
        expect(page).to have_selector("button[aria-expanded='false']", text: I18n.t("activities.education.edit.enrollment_history", count: 1))
        expect(page).to have_no_text(I18n.t("components.enrollment_term_table_component.status.less_than_half_time"))
        continue_without_supplemental_details
      end
    end
  end

  def complete_independent_enrollment
    current = education.less_than_half_time_terms_in_reporting_window.sole
    click_button I18n.t("activities.education.edit.continue")
    verify_page(page, title: I18n.t("activities.education.term_credit_hours.heading", school_name: current.school_name.titlecase))
    select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.less_than_half_time"),
      from: I18n.t("activities.education.add_your_term.edit.enrollment_status")
    fill_in I18n.t("activities.education.add_your_term.edit.credit_hours"), with: "3"
    click_button I18n.t("activities.education.term_credit_hours.continue")
    # Match the existing document-upload specs' heading-order exception.
    verify_page(page, title: I18n.t(education.document_upload_title_i18n_key, name: education.document_upload_object_title),
      skip_axe_rules: %w[heading-order])
    expect(page).to have_current_path(new_activities_flow_education_document_upload_path(education_id: education))
    expect(current.reload.credit_hours).to eq(3)
    calculator = EducationActivityProgressCalculator.new(education.reload)
    expect(calculator.progress_hours_for_month(Date.new(2024, 6, 1))).to eq(3 * EducationActivity::CREDIT_HOUR_CE_MULTIPLIER)
  end

  context "with a newer withdrawal at one school and current enrollment at another" do
    let(:enrollment_codes) { %w[Y W] }
    let(:other_school) { "Other College" }

    it "collects supplemental details only for the other school and credits its hours" do
      expect(education.reload).to be_partially_self_attested
      complete_independent_enrollment
    end
  end

  context "with a newer withdrawal in one term and current enrollment in another" do
    let(:enrollment_codes) { %w[Y W] }
    let(:other_term_end) { "2024-10-31" }

    it "collects supplemental details only for the other term and credits its hours" do
      expect(education.reload).to be_partially_self_attested
      complete_independent_enrollment
    end
  end

  context "when NSC returns only enrolled" do
    let(:enrollment_codes) { %w[Y] }
    let(:term) { education.nsc_enrollment_terms.sole }

    it "shows the enrollment details without a status row" do
      expect(page).to have_selector("tr", text: I18n.t("components.enrollment_term_table_component.student_name_label"))
      expect(page).to have_selector("tr", text: I18n.t("components.enrollment_term_table_component.school_or_program"))
      expect(page).to have_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_term"))
      expect(page).to have_no_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_status"))
    end

    it "collects supplemental details and lets the applicant edit their enrollment status" do
      term.update!(credit_hours: 0)
      create(:nsc_enrollment_term, education_activity: education, enrollment_status: "half_time")
      visit edit_activities_flow_education_term_credit_hour_path(education_id: education, id: 0, from_review: 1, from_edit: 1)
      heading = I18n.t("activities.education.term_credit_hours.heading", school_name: term.school_name.titlecase)
      status_label = I18n.t("activities.education.add_your_term.edit.enrollment_status")
      hours_label = I18n.t("activities.education.add_your_term.edit.credit_hours")
      no_classes_label = I18n.t("activities.education.term_credit_hours.no_hours_checkbox", school_name: term.school_name.titlecase)
      verify_page(page, title: heading)

      expect(page).to have_field(no_classes_label, checked: true, visible: :all)
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.less_than_half_time"), from: status_label
      expect(page).to have_field(no_classes_label, checked: false, visible: :all)
      expect(page).to have_field(hours_label, with: "")
      fill_in hours_label, with: "2.5"
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.full_time"), from: status_label
      expect(page).to have_no_field(hours_label)
      check no_classes_label, allow_label_click: true
      expect(page).to have_select(status_label, selected: I18n.t("activities.education.add_your_term.edit.select_one"))
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.unknown"), from: status_label
      expect(page).to have_field(hours_label, with: "")
      fill_in hours_label, with: "2.5"
      click_button I18n.t("activities.hub.save")
      verify_page(page, title: I18n.t("activities.education.review.title_no_school_name"))
      expect(term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "unknown", credit_hours: BigDecimal("2.5"))

      click_link I18n.t("activities.education.review.edit")
      verify_page(page, title: heading)
      expect(page).to have_select(status_label, selected: I18n.t("activities.education.add_your_term.edit.enrollment_status_options.unknown"))
      select I18n.t("activities.education.add_your_term.edit.enrollment_status_options.half_time"), from: status_label
      click_button I18n.t("activities.hub.save")
      verify_page(page, title: I18n.t("activities.education.review.title_no_school_name"))
      expect(term.reload).to have_attributes(enrollment_status: "enrolled", supplemental_enrollment_status: "half_time", credit_hours: nil)
    end
  end

  context "when NSC returns only less than half-time" do
    let(:enrollment_codes) { %w[L] }

    it "collects credit hours without asking for an enrollment status" do
      click_button I18n.t("activities.education.edit.continue")
      term = education.nsc_enrollment_terms.sole
      verify_page(page, title: I18n.t("activities.education.term_credit_hours.heading", school_name: term.school_name.titlecase))

      expect(page).to have_field(I18n.t("activities.education.add_your_term.edit.credit_hours"))
      expect(page).to have_text(I18n.t("activities.education.add_your_term.edit.credit_hours_hint"))
      expect(page).to have_no_select(I18n.t("activities.education.add_your_term.edit.enrollment_status"))
    end
  end
end
