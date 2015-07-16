require 'disc'

class Echoer
  include Disc::Job
  disc queue: 'test_medium'

  def perform(first, second, third)
    puts "First: #{ first }"
    puts "Second: #{ second }"
    puts "Third: #{ third }"
  end
end
