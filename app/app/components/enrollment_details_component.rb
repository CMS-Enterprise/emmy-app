class EnrollmentDetailsComponent < ViewComponent::Base
  def initialize(enrollment_terms:)
    @enrollment_groups = NscEnrollmentTerm.enrollment_histories(enrollment_terms)
      .map do |latest, *history|
        # NSC W and S both map to withdrawn. Only a prior Y (enrolled) opens history.
        non_enrolled = latest.non_enrolled?
        expanded = non_enrolled && history.any?(&:enrollment_enrolled?)
        visible_history = non_enrolled ? history : history.reject(&:enrollment_enrolled?)
        [ latest, visible_history, expanded ]
      end
  end
end
