module EducationSummaryHelper
  def education_summary_enrollment_status(term, use_enrolled_label: true)
    status = use_enrolled_label && term.enrollment_enrolled? ? t("activities.submit.pdf.enrolled") : term.enrollment_status_display
    return status if term.school_certified_on.blank?

    t("components.enrollment_term_table_component.status_as_of_date",
      status: status, date: format_date(term.school_certified_on))
  end
end
