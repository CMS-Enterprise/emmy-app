# frozen_string_literal: true

class SeasonalJobAccordionComponent < ViewComponent::Base
  def initialize(flow:)
    @flow = flow
  end

  def render?
    @flow.reporting_window_months < 12
  end
end
