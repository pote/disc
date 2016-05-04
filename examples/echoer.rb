require 'disc'

class Echoer
  include Disc::Job
  disc queue: 'test'

  def self.perform(first, second, third)
    puts "First: #{ first }, Second: #{ second }, Third: #{ third }"
  end
end
