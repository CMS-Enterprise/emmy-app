# frozen_string_literal: true

require "rails_helper"

RSpec.describe SeasonalJobAccordionComponent, type: :component do
  let(:activity_flow) { instance_double(ActivityFlow, reporting_window_months: reporting_window_months) }

  context "when the reporting window is less than 12 months" do
    let(:reporting_window_months) { 3 }

    it "renders the seasonal job accordion" do
      render_inline(described_class.new(flow: activity_flow))

      expect(page).to have_content(I18n.t("activities.employment.add_your_work.show.seasonal_job_accordion.title"))
      expect(page).to have_content(I18n.t("activities.employment.add_your_work.show.seasonal_job_accordion.body"))
    end
  end

  context "when the reporting window is 12 months or more" do
    let(:reporting_window_months) { 12 }

    it "does not render the seasonal job accordion" do
      render_inline(described_class.new(flow: activity_flow))

      expect(page).not_to have_selector(".usa-accordion")
      expect(page).not_to have_content(I18n.t("activities.employment.add_your_work.show.seasonal_job_accordion.title"))
    end
  end
end
