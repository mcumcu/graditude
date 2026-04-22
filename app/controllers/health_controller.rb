class HealthController < ApplicationController
  allow_unauthenticated_access only: :up

  def up
    head :ok
  end
end
