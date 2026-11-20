# This is an abstract class that should be inherited by all aggregator report classes.
module Aggregators::AggregatorReports
  class AggregatorReport
    include Cbv::MonthlySummaryHelper

    class NoMatchingEmploymentError < StandardError; end

    attr_accessor :payroll_accounts, :identities, :incomes, :employments, :gigs, :paystubs, :has_fetched, :fetched_days, :reporting_date_range

    def initialize(payroll_accounts: [], days_to_fetch_for_w2: nil, days_to_fetch_for_gig: nil, reporting_date_range: nil)
      @has_fetched = false
      @payroll_accounts = payroll_accounts
      @identities = []
      @incomes = []
      @employments = []
      @paystubs = []
      @gigs = []
      @days_to_fetch_for_w2 = days_to_fetch_for_w2
      @days_to_fetch_for_gig = days_to_fetch_for_gig
      @fetched_days = days_to_fetch_for_w2
      @reporting_date_range = reporting_date_range
    end

    def fetch
      return false unless is_ready_to_fetch?
      fetch_report_data
    end

    def has_fetched?
      @has_fetched
    end

    def flow
      @payroll_accounts.first.flow
    end

    def is_ready_to_fetch?
      @payroll_accounts.all? do |payroll_account|
        payroll_account.has_fully_synced?
      end
    end

    def fetch_report_data
      begin
        all_successful = true
        @payroll_accounts.each do |payroll_account|
          fetch_report_data_for_account(payroll_account)
        end
      rescue StandardError => e
        Rails.logger.error("Report Fetch Error: #{e.message}")
        all_successful = false
      end
      @has_fetched = all_successful
    end

    AccountReportStruct = Struct.new(:identity, :income, :employment, :paystubs, :gigs)
    def find_account_reports(account_id)
      relevant_employments = pick_employments(@employments, account_id)

      if relevant_employments.empty?
        Rails.logger.warn("Skipping account #{account_id}: No relevant employments found")
        return []
      end

      relevant_employments.map do |employment|
        employment_filter = employment_filter_for(account_id, employment&.employment_matching_id)

        # Note that, once we filter by employment match, we do not yet have a good solution for displaying multiple
        # incomes or identities at this time. We just take the first.
        AccountReportStruct.new(
          @identities.filter(&employment_filter).first,
          @incomes.filter(&employment_filter).first,
          employment,
          @paystubs.filter(&employment_filter),
          @gigs.find_all { |gig| gig.account_id == account_id }
        )
      end
    end

    def income_report
      {
        has_other_jobs: flow.has_other_jobs,
        employments: income_report_employments
      }
    end

    def income_report_employments
      summarize_by_employer.map do |report_key, summary|
        # report_key is now "#{account_id}_#{employment_matching_id}" or just "account_id"
        account_id = report_key.include?("_") ? report_key.split("_", 2).first : report_key
        cbv_flow = flow
        payroll_account = cbv_flow.payroll_accounts.find do |account|
          account.aggregator_account_id == account_id
        end
        {
          applicant_full_name: summary[:identity]&.full_name,
          applicant_ssn: summary[:identity]&.ssn,
          applicant_extra_comments: payroll_account&.additional_information,
          employer_name: summary[:employment]&.employer_name,
          employer_phone: summary[:employment]&.employer_phone_number,
          employer_address: summary[:employment]&.employer_address,
          employment_status: summary[:employment]&.status,
          employment_type: summary[:employment]&.employment_type,
          employment_start_date: summary[:employment]&.start_date,
          employment_end_date: summary[:employment]&.termination_date,
          pay_frequency: summary[:income]&.pay_frequency,
          compensation_amount: summary[:income]&.compensation_amount,
          compensation_unit: summary[:income]&.compensation_unit,
          paystubs: (summary[:paystubs] || []).map do |paystub|
            {
              pay_date: paystub.pay_date,
              pay_period_start: paystub.pay_period_start,
              pay_period_end: paystub.pay_period_end,
              pay_gross: paystub.gross_pay_amount || 0,
              gross_pay_list: (paystub.earnings || []).filter_map do |earning|
                next if earning.amount.nil?

                {
                  type: earning.category,
                  amount: earning.amount
                }
              end,
              pay_gross_ytd: paystub.gross_pay_ytd,
              pay_net: paystub.net_pay_amount,
              hours_paid: paystub.hours,
              deductions: (paystub.deductions || []).map(&:to_h)
            }
          end
        }
      end
    end

    def summarize_by_employer
      @payroll_accounts.each_with_object({}) do |payroll_account, hash|
        account_id = payroll_account.aggregator_account_id
        account_reports = find_account_reports(account_id)

        next if account_reports.empty?

        has_income_data = payroll_account.job_succeeded?("income")
        has_employment_data = payroll_account.job_succeeded?("employment")
        has_identity_data = payroll_account.job_succeeded?("identity")
        has_paystubs_data = payroll_account.job_succeeded?("paystubs")

        account_reports.each do |account_report|
          # If there are multiple employments for the same account, we use a unique key
          # combining account_id and employment_matching_id to avoid collisions in the hash.
          # If employment_matching_id is missing (e.g. in some tests or for Pinwheel), we fall back to account_id.
          employment_id = account_report.employment.employment_matching_id
          report_key = employment_id.present? ? "#{account_id}_#{employment_id}" : account_id

          hash[report_key] ||= {
            total: account_report.paystubs.sum { |paystub| paystub.gross_pay_amount || 0 },
            has_income_data: has_income_data,
            has_employment_data: has_employment_data,
            has_identity_data: has_identity_data,
            employment: has_employment_data ? account_report.employment : nil,
            income: has_income_data ? account_report.income : nil,
            identity: has_identity_data ? account_report.identity : nil,
            paystubs: has_paystubs_data ? account_report.paystubs : nil,
            gigs: account_report.gigs
          }
        end
      end
    end

    def summarize_by_month(from_date: nil, to_date: nil)
      from_date = parse_date_safely(self.from_date) if from_date.nil?
      to_date = parse_date_safely(self.to_date) if to_date.nil?

      @payroll_accounts
        .each_with_object({}) do |payroll_account, hash|
          account_id = payroll_account.aggregator_account_id
          account_reports = find_account_reports(account_id)

          next if account_reports.empty?

          account_reports.each do |account_report|
            paystubs = account_report.paystubs
            gigs = account_report.gigs
            extracted_dates = extract_dates(paystubs, gigs)
            months = unique_months(extracted_dates)

            # Group paystubs and gigs by month
            employment_id = account_report.employment.employment_matching_id
            report_key = employment_id.present? ? "#{account_id}_#{employment_id}" : account_id
            hash[report_key] ||= months.each_with_object({}) do |month, result|
              month_string = month.strftime("%Y-%m")
              month_beginning = month.beginning_of_month
              month_end = month.end_of_month

              paystubs_in_month = paystubs.select { |paystub| parse_date_safely(paystub.pay_date)&.between?(month_beginning, month_end) }
              gigs_in_month = gigs.select { |gig| parse_date_safely(gig.end_date)&.between?(month_beginning, month_end) }
              extracted_dates_in_month = extract_dates(paystubs_in_month, gigs_in_month)

              result[month_string] = {
                paystubs: paystubs_in_month,
                gigs: gigs_in_month,
                accrued_gross_earnings: paystubs_in_month.sum { |paystub| paystub.gross_pay_amount || 0 },
                total_gig_hours: gigs_in_month.sum { |gig| gig.hours || 0 },
                total_w2_hours: paystubs_in_month.sum { | paystub | paystub.hours.to_f },
                total_mileage: total_miles(gigs_in_month),
                partial_month_range: partial_month_details(month, extracted_dates_in_month, from_date, to_date)
              }
            end
          end
        end
    end

    def total_miles(gigs)
      gigs.sum { |g| g.mileage || 0 }
    end

    def total_gross_income
      @paystubs.reduce(0) { |sum, paystub| sum + (paystub.gross_pay_amount || 0) }
    end

    def days_since_last_paydate
      latest_paystub_date = paystubs.map(&:pay_date).compact.map { |pay_date| Date.parse(pay_date) }.max
      return nil if latest_paystub_date.nil?
      (Date.current - latest_paystub_date).to_i
    end

    def from_date
      # For Activity flows, use the reporting_date_range start date directly
      return @reporting_date_range.begin if @reporting_date_range.present?

      # If @fetched_days is nil, default to a reasonable period (e.g. 90 days)
      days = @fetched_days || 90
      days.days.ago.to_date
    end

    def to_date
      # For Activity flows, use the reporting_date_range end date directly
      return @reporting_date_range.end if @reporting_date_range.present?

      # Use the CBV flow as the basis for the end of the report range, as it
      # reflects the actual time that the user was completing the flow (as
      # opposed to the invitation, which they could have been sitting on for
      # many days.)
      flow.created_at.to_date
    end

    def fetched_days_for_account(account_id)
      account_employments = pick_employments(@employments, account_id)
      return @fetched_days if account_employments.empty?

      # If there are multiple employments, we want to be conservative and fetch
      # for the longer duration if they differ.
      types = account_employments.map(&:employment_type).uniq

      if types.include?(:w2) && types.include?(:gig)
        [@days_to_fetch_for_w2, @days_to_fetch_for_gig].compact.max || @fetched_days
      elsif types.include?(:w2)
        @days_to_fetch_for_w2 || @fetched_days
      elsif types.include?(:gig)
        @days_to_fetch_for_gig || @fetched_days
      else
        @fetched_days
      end
    end

    private

    def employment_filter_for(account_id, employment_matching_id)
      # Create a filter that filters any entities that don't match the account id and the employment id.
      # If the entity doesn't have an employment id, allow it (eg for Pinwheel)
      lambda do |item|
        item.account_id == account_id &&
          (item.employment_id.nil? || item.employment_id == employment_matching_id)
      end
    end

    def pick_employment_income_only(employments, paystubs, account_id)
      # In Argyle, the employments endpoint can return more than one employment.
      # This method chooses the employment we want to use. Later, we must filter related
      # data sets to make sure we're only using ones that match the employment ID we chose here.
      relevant_employments = employments.select { |e| e[:account_id] == account_id }
      if relevant_employments.empty?
        Rails.logger.error("No employments found that match account_id #{account_id} out of #{employments.count} employments")
        raise NoMatchingEmploymentError, "No employments found that match account_id #{account_id}"
      end

      # Pick the employment with the latest update when considering the start_date,
      # terminated_at, and any related paystub's pay_date properties.
      relevant_employments.max_by do |emp|
        relevant_paystubs = paystubs.select { |p| p[:employment_id] == emp.employment_matching_id }

        all_dates = [
          emp[:start_date],
          emp[:termination_date]
        ] + relevant_paystubs.map { |p| p[:pay_date] }

        # In case an employment has no non-nil dates, default to something really early.
        all_dates.compact.max || "1900-01-01"
      end
    end

    def pick_employments(employments, account_id)
      # Emmy Income (CbvFlow) should only ever have a single employment picked.
      if flow.is_a?(CbvFlow)
        begin
          return [pick_employment_income_only(employments, @paystubs || [], account_id)].compact
        rescue NoMatchingEmploymentError
          return []
        end
      end

      # Returns all employments relevant to the time period being collected for a specific account.
      # This considers whether the employment was active at any point during the reporting range.
      report_from = parse_date_safely(from_date)
      report_to = parse_date_safely(to_date)

      results = employments.select do |emp|
        next false unless emp[:account_id] == account_id

        emp_start = parse_date_safely(emp[:start_date])
        emp_end = parse_date_safely(emp[:termination_date])

        # An employment is relevant if it started on or before the end of the report period
        # AND (it has not ended OR it ended on or after the start of the report period)
        started_before_end = emp_start.nil? || emp_start <= report_to
        ended_after_start = emp_end.nil? || emp_end >= report_from

        started_before_end && ended_after_start
      end

      # If no employments were active during the reporting period, fallback to picking the most
      # recent employment regardless of dates. This ensures we show something if the user has
      # linked an account but we can't determine relevancy from dates alone, which matches
      # the previous behavior of pick_employment.
      if results.empty? && employments.any? { |e| e[:account_id] == account_id }
        begin
          results = [pick_employment_income_only(employments, @paystubs || [], account_id)].compact
        rescue NoMatchingEmploymentError
          results = []
        end
      end

      results
    end
  end
end
