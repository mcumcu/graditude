class RenameProdigiPipelineRunErrorsToErrorDetails < ActiveRecord::Migration[8.1]
  def change
    rename_column :prodigi_pipeline_runs, :errors, :error_details
  end
end
