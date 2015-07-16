require 'disc'

class Echoer
  include Disc::Job
  disc queue: 'test_urgent'

  def perform(first, second, third)
    puts "First: #{ first }, Second: #{ second }, Third: #{ third }"
  end
end
