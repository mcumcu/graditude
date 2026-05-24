class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :affiliate
  delegate :user, to: :session, allow_nil: true
end
