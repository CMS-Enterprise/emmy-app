# frozen_string_literal: true

class SeasonalJobAccordionComponent < ViewComponent::Base
  def initialize(flow:, heading_level: 3)
    @flow = flow
    @heading_level = heading_level
  end

  def render?
    @flow.employment_focused? && @flow.reporting_window_months < 12
  end
end
