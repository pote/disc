require 'cutest'
require 'disc'

require_relative '../examples/echoer'

prepare do
  Disc.disque_timeout = 1 # 1ms so we don't wait at all.
  Disc.flush
end

scope do
  test 'jobs are enqueued to the correct Disque queue with appropriate parameters and class' do
    job_id = Echoer.enqueue(['one argument', { random: 'data' }, 3])

    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.count

    jobs.first.tap do |queue, id, serialized_job|
      job = Disc.deserialize(serialized_job)

      assert job.has_key?('class')
      assert job.has_key?('arguments')

      assert_equal 'Echoer', job['class']
      assert_equal job_id, id

      args = job['arguments']
      assert_equal 3, args.size
      assert_equal 'one argument', args[0]
      assert_equal({ 'random' => 'data' }, args[1])
      assert_equal(3, args[2])
    end
  end

  test 'enqueue at timestamp behaves properly' do
    job_id = Echoer.enqueue(['one argument', { random: 'data' }, 3], at: Time.now + 1)

    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 0.5
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 0.5
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.size

    jobs.first.tap do |queue, id, serialized_job|
      assert_equal 'test', queue
      assert_equal job_id, id
      job = Disc.deserialize(serialized_job)
      assert job.has_key?('class')
      assert job.has_key?('arguments')
      assert_equal 'Echoer', job['class']
      assert_equal 3, job['arguments'].size
    end
  end

  test 'enqueue supports replicate' do
    error = Echoer.enqueue(['one argument', { random: 'data' }, 3], replicate: 100) rescue $!

    assert_equal RuntimeError, error.class
    assert_equal "NOREPL Not enough reachable nodes for the requested replication level", error.message
  end

  test 'enqueue supports delay' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3], delay: 2)

    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 1
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 2
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.size
  end

  test 'enqueue supports retry' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3], retry: 1)

    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.size

    sleep 1.5
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.size
  end

  test 'enqueue supports ttl' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3], ttl: 1)

    sleep 1.5
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?
  end

  test 'enqueue supports maxlen' do
    Echoer.enqueue(['one argument', { random: 'data' }, 3], maxlen: 1)
    error = Echoer.enqueue(['one argument', { random: 'data' }, 3], maxlen: 1) rescue $!

    assert_equal RuntimeError, error.class
    assert_equal "MAXLEN Queue is already longer than the specified MAXLEN count", error.message
  end

  test 'enqueue supports async' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3], async: true)

    sleep 1 # async is too fast to reliably assert an empty queue, let's wait instead
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.size
  end
end
