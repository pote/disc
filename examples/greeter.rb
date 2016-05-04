require 'disc'

class Greeter
  include Disc::Job
  disc queue: 'test_medium'

  def self.perform(string)
    $stdout.puts(string)
  end
end
