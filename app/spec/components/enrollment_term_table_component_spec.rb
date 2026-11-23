require "rails_helper"

RSpec.describe EnrollmentTermTableComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new(nsc_enrollment_term: term)) }

  let(:status) { :half_time }

  let(:term) do
    NscEnrollmentTerm.new(
      enrollment_status: status, school_name: "Test College", first_name: "Test", last_name: "Student",
      term_begin: Date.new(2024, 1, 1), term_end: Date.new(2024, 6, 30)
    )
  end

  it "keeps school information separate from all term-related fields" do
    school_table = rendered.css("table").first
    term_table = rendered.css("table")[1]

    expect(rendered).to have_selector("h3", text: I18n.t("activities.summary.education.enrollment_details"))
    expect(rendered).to have_selector("h3", text: I18n.t("activities.summary.education.term_details"))
    expect(school_table).to have_text(term.school_name)
    expect(school_table).to have_no_text(I18n.l(term.term_begin, format: :long))
    expect(school_table).to have_no_text(term.enrollment_status_display)
    expect(term_table).to have_text(I18n.l(term.term_begin, format: :long))
    expect(term_table).to have_text(term.enrollment_status_display)
    expect(term_table).to have_text(I18n.t("activities.summary.education.term_credit_hours"))
    expect(term_table).to have_text(I18n.t("activities.summary.education.community_engagement_hours"))
    expect(term_table).to have_no_text(term.school_name)
  end

  context "with full-time enrollment on review pages" do
    let(:status) { :full_time }

    it "shows the status without certification dates or enrollment history" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.full_time"))
      expect(rendered).to have_no_text("As of")
      expect(rendered).to have_no_button("View enrollment history")
    end
  end

  context "with a leave of absence" do
    let(:status) { :leave_of_absence }

    it "displays leave of absence" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.leave_of_absence"))
    end
  end

  context "with a withdrawal" do
    let(:status) { :withdrawn }

    it "displays withdrawn" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.withdrawn"))
    end
  end

  context "with graduation" do
    let(:status) { :graduated }

    it "displays graduated" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.graduated"))
    end
  end

  context "with a deceased student" do
    let(:status) { :deceased }

    it "displays deceased" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.deceased"))
    end
  end

  context "when the school has not released the enrollment status" do
    let(:status) { :enrolled }

    it "describes the meaning of the raw Y code" do
      expect(rendered).to have_text(I18n.t("components.enrollment_term_table_component.status.enrolled"))
    end

    context "when the status row is hidden" do
      subject(:rendered) { render_inline(described_class.new(nsc_enrollment_term: term, show_enrollment_status: false)) }

      it "omits the enrollment status row" do
        expect(rendered).to have_no_selector("tr", text: I18n.t("components.enrollment_term_table_component.enrollment_status"))
      end
    end
  end
end
