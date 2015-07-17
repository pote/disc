require 'disc'

class Greeter
  include Disc::Job
  disc queue: 'test_medium'

  def perform(string)
    $stdout.puts(string)
  end
end
