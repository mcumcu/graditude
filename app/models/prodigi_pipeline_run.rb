class ProdigiPipelineRun < ApplicationRecord
  validates :phase, presence: true
  validates :status, presence: true

  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, suffix: true
end
