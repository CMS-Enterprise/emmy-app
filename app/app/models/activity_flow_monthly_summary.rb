# frozen_string_literal: true

class ActivityFlowMonthlySummary < ApplicationRecord
  include Redactable

  belongs_to :activity_flow
  belongs_to :payroll_account

  validates :month, presence: true
  validates :activity_flow_id, uniqueness: { scope: %i[payroll_account_id employer_id month] }

  # Loads persisted summaries and reshapes them into the format the progress
  # calculator and views expect (account_id => employer_id => month => data).
  # Returns nil when data is incomplete so callers know to fall back to the API.
  def self.load_complete_summary_data(activity_flow:)
    synced_accounts = activity_flow.payroll_accounts.published.select(&:sync_succeeded?)
    return nil if synced_accounts.empty?

    months = activity_flow.reporting_months.map(&:beginning_of_month)
    expected_count = synced_accounts.size * months.size
    rows = activity_flow.activity_flow_monthly_summaries
                        .unredacted
                        .where(month: months)
                        .where(payroll_account_id: synced_accounts.map(&:id))
                        .includes(:payroll_account)
    if rows.size < expected_count
      Rails.logger.info "ActivityFlowMonthlySummary incomplete for flow #{activity_flow.id}: #{rows.size}/#{expected_count} rows, using fallback"
      return nil
    end

    rows
      .group_by { |row| row.payroll_account.aggregator_account_id }
      .transform_values do |account_rows|
      account_rows.index_by { |row| row.month.strftime("%Y-%m") }.transform_values do |row|
        {
          total_w2_hours: row.total_w2_hours.to_f,
          total_gig_hours: row.total_gig_hours.to_f,
          accrued_gross_earnings: row.accrued_gross_earnings_cents.to_i,
          total_mileage: row.total_mileage.to_f,
          paychecks_count: row.paychecks_count.to_i
        }
      end
    end
  end

  def self.by_account_employer_with_fallback(activity_flow:)
    persisted = load_complete_summary_data(activity_flow: activity_flow)
    return persisted if persisted

    report = AggregatorReportFetcher.new(activity_flow).report
    return {} unless report&.has_fetched?

    activity_flow.payroll_accounts.published.select(&:sync_succeeded?).each do |payroll_account|
      upsert_from_report(activity_flow: activity_flow, payroll_account: payroll_account, report: report)
      ActivityFlowEmploymentSummary.persist_from_report(activity_flow: activity_flow, payroll_account: payroll_account, report: report)
    end

    load_complete_summary_data(activity_flow: activity_flow) || {}
  end

  def self.by_account_with_fallback(activity_flow:)
    persisted = load_complete_summary_data(activity_flow: activity_flow)
    return persisted if persisted

    report = AggregatorReportFetcher.new(activity_flow).report
    return {} unless report&.has_fetched?

    activity_flow.payroll_accounts.published.select(&:sync_succeeded?).each do |payroll_account|
      upsert_from_report(activity_flow: activity_flow, payroll_account: payroll_account, report: report)
      ActivityFlowEmploymentSummary.persist_from_report(activity_flow: activity_flow, payroll_account: payroll_account, report: report)
    end

    load_complete_summary_data(activity_flow: activity_flow) || {}
  end

  def self.upsert_from_report(activity_flow:, payroll_account:, report:)
    return unless report.has_fetched?

    range = activity_flow.reporting_window_range
    aggregator_account_id = payroll_account.aggregator_account_id
    all_months_data = report.summarize_by_month(from_date: range.begin, to_date: range.end)
    reporting_months = activity_flow.reporting_months

    # Find all report keys that match this account (could be "acct-1" or "acct-1_emp-1")
    relevant_report_keys = all_months_data.keys.select do |key|
      key == aggregator_account_id || key.start_with?("#{aggregator_account_id}_")
    end

    relevant_report_keys.each do |report_key|
      months_data = all_months_data[report_key] || {}
      employer_id = report_key.include?("_") ? report_key.split("_", 2).last : nil

      reporting_months.each do |month_date|
        month_string = month_date.strftime("%Y-%m")
        data = months_data[month_string] || {}

        upsert(
          {
            activity_flow_id: activity_flow.id,
            payroll_account_id: payroll_account.id,
            employer_id: employer_id,
            month: month_date.beginning_of_month,
            total_w2_hours: data[:total_w2_hours].to_f,
            total_gig_hours: data[:total_gig_hours].to_f,
            accrued_gross_earnings_cents: (data[:accrued_gross_earnings] || 0).to_i,
            total_mileage: (data[:total_mileage] || 0).to_f,
            paychecks_count: (data[:paystubs]&.size || 0).to_i
          },
          unique_by: :index_activity_flow_monthly_summaries_on_flow_acc_emp_month,
          update_only: %i[
            total_w2_hours total_gig_hours accrued_gross_earnings_cents
            total_mileage paychecks_count
          ]
        )
      end
    end
  end

  # Redact all persisted income details for this monthly summary row.
  def redact!
    assign_attributes(
      total_w2_hours: 0,
      total_gig_hours: 0,
      accrued_gross_earnings_cents: 0,
      total_mileage: 0,
      paychecks_count: 0,
      redacted_at: Time.current
    )
    save(validate: false)
  end
end
