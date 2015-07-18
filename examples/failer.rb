require 'disc'

def Disc.on_error(exception, job)
  $stdout.puts('<insert error reporting here>')
  $stdout.puts(exception.message)
  $stdout.puts(job)
end

class Failer
  include Disc::Job
  disc queue: 'test'

  def perform(string)
    raise string
  end
end
