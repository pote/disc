require 'disc'

class Identifier
  include Disc::Job
  disc queue: 'test'

  def perform
    $stdout.puts("Working with Disque ID: #{ self.disque_id }")
  end
end
