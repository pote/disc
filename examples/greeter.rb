require 'disc'

class Greeter
  include Disc::Job
  self.queue = 'test_medium'

  def perform(string)
    $stdout.puts(string)
  end
end
