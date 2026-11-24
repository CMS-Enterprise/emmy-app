class AddEmployerIdToActivityFlowMonthlySummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_monthly_summaries, :employer_id, :string
  end
end
