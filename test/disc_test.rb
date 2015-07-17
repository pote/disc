require 'cutest'
require 'disc'
require 'msgpack'
require 'pty'

require_relative '../examples/echoer'

prepare do
  Disc.disque.call('DEBUG', 'FLUSHALL')
end

scope do
  test 'jobs are enqueued to the correct Disque queue with appropriate parameters and class' do
    jobid = Echoer.enqueue('one argument', { random: 'data' }, 3)

    jobs = Array(Disc.disque.fetch(from: ['test_urgent'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.count

    jobs.first.tap do |queue, id, serialized_job|
      job = MessagePack.unpack(serialized_job)

      assert job.has_key?('class')
      assert job.has_key?('arguments')

      assert_equal 'Echoer', job['class']
      assert_equal jobid, id

      args = job['arguments']
      assert_equal 3, args.size
      assert_equal 'one argument', args[0]
      assert_equal({ 'random' => 'data' }, args[1])
      assert_equal(3, args[2])
    end
  end

  test 'enqueue_at behaves properly' do
    in_3_seconds = (Time.now + 3).to_datetime
    jobid = Echoer.enqueue_at(in_3_seconds, 'one argument', { random: 'data' }, 3)

    jobs = Array(Disc.disque.fetch(from: ['test_urgent'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 1
    jobs = Array(Disc.disque.fetch(from: ['test_urgent'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 2
    jobs = Array(Disc.disque.fetch(from: ['test_urgent'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.size

    jobs.first.tap do |queue, id, serialized_job|
      assert_equal 'test_urgent', queue
      assert_equal jobid, id
      job = MessagePack.unpack(serialized_job)
      assert job.has_key?('class')
      assert job.has_key?('arguments')
      assert_equal 'Echoer', job['class']
      assert_equal 3, job['arguments'].size
    end
  end

  test 'jobs are executed' do
    begin
      Echoer.enqueue('one argument', { random: 'data' }, 3)

      cout, _, pid = PTY.spawn(
        'QUEUES=test_urgent ruby -Ilib bin/disc -r ./examples/echoer'
      )
      sleep 0.5

      jobs = Disc.disque.fetch(from: ['test_urgent'], timeout: Disc.disque_timeout, count: 1)
      assert jobs.nil?

      matched = false
      counter = 0
      while !matched && counter < 5
        counter += 1
        matched = cout.gets.match(/First: one argument, Second: {"random"=>"data"}, Third: 3/)
        sleep(1) unless matched
      end

      assert matched
    ensure
      Process.kill("KILL", pid)
    end
  end
end
