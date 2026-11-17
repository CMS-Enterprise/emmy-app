class EnrollmentDetailsComponent < ViewComponent::Base
  def initialize(enrollment_terms:)
    @enrollment_groups = enrollment_terms
      .group_by { |term| [ term.school_name, term.term_begin, term.term_end ] }
      .values
      .map do |terms|
        latest, *history = terms.sort_by { |term| [ term.school_certified_on || Date.new(1, 1, 1), term.id || 0 ] }.reverse
        # NSC W and S both map to withdrawn. Only a prior Y (enrolled) opens history.
        non_enrolled = latest.non_enrolled?
        expanded = non_enrolled && history.any?(&:enrollment_enrolled?)
        visible_history = non_enrolled ? history : history.reject(&:enrollment_enrolled?)
        [ latest, visible_history, expanded ]
      end
  end
end
