require 'cutest'
require 'disc'
require 'pty'
require 'timeout'

require_relative '../examples/echoer'
# class Echoer
#   include Disc::Job
#   disc queue: 'test'
#
#   def perform(first, second, third)
#     puts "First: #{ first }, Second: #{ second }, Third: #{ third }"
#   end
# end

require_relative '../examples/failer'
# def Disc.on_error(exception, job)
#   $stdout.puts('<insert error reporting here>')
#   $stdout.puts(exception.message)
#   $stdout.puts(job)
# end
#
# class Failer
#   include Disc::Job
#   disc queue: 'test'
# 
#   def perform(string)
#     raise string
#   end
# end

prepare do
  Disc.disque_timeout = 1 # 1ms so we don't wait at all.
  Disc.flush
end

scope do
  # Runs a given command, yielding the stdout (as an IO) and the PID (a String).
  # Makes sure the process finishes after the block runs.
  def run(command)
    out, _, pid = PTY.spawn(command)
    yield out, pid
  ensure
    Process.kill("KILL", pid)
    sleep 0.1 # Make sure we give it time to finish.
  end

  # Checks whether a process is running.
  def is_running?(pid)
    Process.getpgid(pid)
    true
  rescue Errno::ESRCH
    false
  end

  test 'jobs are enqueued to the correct Disque queue with appropriate parameters and class' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3])

    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.any?
    assert_equal 1, jobs.count

    jobs.first.tap do |queue, id, serialized_job|
      job = Disc.deserialize(serialized_job)

      assert job.has_key?('class')
      assert job.has_key?('arguments')

      assert_equal 'Echoer', job['class']
      assert_equal job_instance.disque_id, id

      args = job['arguments']
      assert_equal 3, args.size
      assert_equal 'one argument', args[0]
      assert_equal({ 'random' => 'data' }, args[1])
      assert_equal(3, args[2])
    end
  end

  test 'we get easy access to the job via the job id' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3])

    assert job_instance.is_a?(Echoer)
    assert !job_instance.disque_id.nil?
    assert !job_instance.info.nil?

    job = Echoer[job_instance.disque_id]

    assert job.is_a?(Echoer)
    assert_equal 'queued', job.state
    assert_equal 3, job.arguments.count
    assert_equal 'one argument', job.arguments.first
  end

  test 'we can query the lenght of a given queue' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3])

    assert_equal 1, Disc.qlen(Echoer.queue)
  end

  test 'enqueue at timestamp behaves properly' do
    job_instance = Echoer.enqueue(['one argument', { random: 'data' }, 3], at: Time.now + 1)

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
      assert_equal job_instance.disque_id, id
      job = Disc.deserialize(serialized_job)
      assert job.has_key?('class')
      assert job.has_key?('arguments')
      assert_equal 'Echoer', job['class']
      assert_equal 3, job['arguments'].size
    end
  end

  test 'jobs are executed' do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])

    run('QUEUES=test ruby -Ilib bin/disc -r ./examples/echoer') do |cout, pid|
      output = Timeout.timeout(1) { cout.take(3) }
      jobs = Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1)
      assert jobs.nil?
      assert output.grep(/First: one argument, Second: {"random"=>"data"}, Third: 3/).any?
    end
  end

  test 'Disc.on_error will catch unhandled exceptions and keep disc alive' do
    failer = Failer.enqueue('this can only end positively')

    run('QUEUES=test ruby -Ilib bin/disc -r ./examples/failer') do |cout, pid|
      output = Timeout.timeout(1) { cout.take(5) }
      jobs = Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1)
      assert jobs.nil?

      assert output.grep(/<insert error reporting here>/).any?
      assert output.grep(/this can only end positively/).any?
      assert output.grep(/Failer/).any?

      assert is_running?(pid)
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
