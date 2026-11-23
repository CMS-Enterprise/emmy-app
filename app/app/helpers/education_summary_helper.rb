module EducationSummaryHelper
  def education_summary_enrollment_status(term, use_enrolled_label: true)
    status = use_enrolled_label && term.enrollment_enrolled? ? t("activities.submit.pdf.enrolled") : term.enrollment_status_display
    return status if term.school_certified_on.blank?

    safe_join([ status, tag.em(t("activities.summary.education.certification_date",
      date: format_date(term.school_certified_on))) ], " ")
  end
end
