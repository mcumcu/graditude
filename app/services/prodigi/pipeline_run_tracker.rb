module Prodigi
  class PipelineRunTracker
    def self.track(phase:, summary: {})
      run = ProdigiPipelineRun.create!(phase: phase, status: :running, started_at: Time.current, summary: summary)

      result = yield(run)

      update_run!(run, :completed, result)
      result
    rescue StandardError => error
      update_run!(run, :failed, { error_details: { message: error.message } }) if run
      raise
    end

    def self.update_run!(run, status, result)
      attributes = {
        status: status,
        finished_at: Time.current,
        record_count: result.fetch(:record_count, result.fetch(:processed, 0)),
        created_count: result.fetch(:created, run.created_count),
        updated_count: result.fetch(:updated, run.updated_count),
        failed_count: result.fetch(:failed, run.failed_count),
        summary: result.fetch(:summary, result)
      }

      error_payload = result.is_a?(Hash) ? result[:error_details] : nil
      run.update!(attributes)
      run.update_columns(error_details: error_payload, updated_at: Time.current) if error_payload
    end

    private_class_method :update_run!
  end
end
