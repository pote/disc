require 'disc'

class Failer
  include Disc::Job
  disc queue: 'test_medium'

  def perform
    raise 'I just failed!'
  end
end

