class CreateProdigiPipelineRuns < ActiveRecord::Migration[8.1]
  def change
    drop_table :prodigi_pipeline_runs, if_exists: true
    create_table :prodigi_pipeline_runs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :phase, null: false
      t.string :status, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :record_count, default: 0, null: false
      t.integer :created_count, default: 0, null: false
      t.integer :updated_count, default: 0, null: false
      t.integer :failed_count, default: 0, null: false
      t.jsonb :summary, null: false, default: {}
      t.jsonb :errors, null: false, default: {}
      t.timestamps
    end

    remove_index :prodigi_pipeline_runs, :phase, if_exists: true
    remove_index :prodigi_pipeline_runs, :status, if_exists: true
    add_index :prodigi_pipeline_runs, :phase
    add_index :prodigi_pipeline_runs, :status
  end
end
