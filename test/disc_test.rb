$: << 'lib'
require 'cutest'
require 'disc'

class TestJob
  include Disc::Job
  disc queue: 'test_urgent'

  def perform(argument)
    puts argument
  end
end

scope do
  test 'basic enqueuing works' do
    original_length = Disc.disque.call('QLEN', 'test_urgent').to_i

    TestJob.enqueue(random: 'data')

    assert Disc.disque.call('QLEN', 'test_urgent').to_i == original_length + 1
  end
end
