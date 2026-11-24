# frozen_string_literal: true

require "rails_helper"

RSpec.describe SeasonalJobAccordionComponent, type: :component do
  let(:activity_flow) do
    instance_double(
      ActivityFlow,
      reporting_window_months: reporting_window_months,
      employment_focused?: employment_focused
    )
  end
  let(:employment_focused) { true }

  context "when the flow is employment focused" do
    let(:employment_focused) { true }

    context "when the reporting window is less than 12 months" do
      let(:reporting_window_months) { 3 }

      it "renders the seasonal job accordion" do
        render_inline(described_class.new(flow: activity_flow))

        expect(page).to have_content(I18n.t("activities.employment.add_your_work.show.seasonal_job_accordion.title"))
        expect(page).to have_content(I18n.t("activities.employment.add_your_work.show.seasonal_job_accordion.body"))
      end

      it "uses the passed heading level" do
        render_inline(described_class.new(flow: activity_flow, heading_level: 2))

        expect(page).to have_selector("h2", text: I18n.t("activities.employment.add_your_work.show.seasonal_job_accordion.title"))
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

  context "when the flow is not employment focused" do
    let(:employment_focused) { false }

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
end
