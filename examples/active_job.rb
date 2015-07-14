class IncrediblyActiveJob < ActiveJob::Base
  queue_as :test_medium

  def perform(something)
    puts something
  end
end
