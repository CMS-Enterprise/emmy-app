class AddEmployerIdAndSelectedToActivityFlowEmploymentSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_employment_summaries, :employer_id, :string
    add_column :activity_flow_employment_summaries, :selected, :boolean, default: true, null: false
  end
end
