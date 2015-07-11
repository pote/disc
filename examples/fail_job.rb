require 'disc'

class FailJob
  include Disc::Job
  disc queue: 'test_medium'

  def perform(string)
    raise string
  end
end
