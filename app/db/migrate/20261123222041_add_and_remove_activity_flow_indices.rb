class AddAndRemoveActivityFlowIndices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  def change
    remove_index :activity_flow_monthly_summaries, name: :index_activity_flow_monthly_summaries_on_flow_account_month
    add_index :activity_flow_monthly_summaries, [:activity_flow_id, :payroll_account_id, :employer_id, :month], unique: true, name: :index_activity_flow_monthly_summaries_on_flow_acc_emp_month, algorithm: :concurrently
    remove_index :activity_flow_employment_summaries, name: :index_activity_flow_employment_summaries_on_flow_account
    add_index :activity_flow_employment_summaries, [:activity_flow_id, :payroll_account_id, :employer_id], unique: true, name: :index_activity_flow_employment_summaries_on_flow_acc_emp, algorithm: :concurrently
  end
end
