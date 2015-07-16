require 'cutest'
require 'disc'
require 'msgpack'

class TestJob
  include Disc::Job
  disc queue: 'test_urgent'

  def perform(first, second, third)
    puts "First: #{ first }"
    puts "Second: #{ second }"
    puts "Third: #{ third }"
  end
end

prepare do
  Disc.disque.call('DEBUG', 'FLUSHALL')
end

scope do
  test 'jobs are enqueued to the correct Disque queue with appropriate parameters and class' do
    TestJob.enqueue('one argument', { random: 'data' }, 3)

    jobs = Array(Disc.disque.fetch(from: ['test_urgent'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.count

    jobs.first.tap do |queue, _, serialized_job|
      job = MessagePack.unpack(serialized_job)

      assert job.has_key?('class')
      assert job.has_key?('arguments')

      assert_equal 'TestJob', job['class']

      args = job['arguments']
      assert_equal 3, args.size
      assert_equal 'one argument', args[0]
      assert_equal({ 'random' => 'data' }, args[1])
      assert_equal(3, args[2])
    end
  end
end
