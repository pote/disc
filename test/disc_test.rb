require 'cutest'
require 'disc'
require 'msgpack'
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
  Disc.disque.call('DEBUG', 'FLUSHALL')
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
    jobid = Echoer.enqueue(['one argument', { random: 'data' }, 3])

    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
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

  test 'enqueue at timestamp behaves properly' do
    jobid = Echoer.enqueue(['one argument', { random: 'data' }, 3], at: Time.now + 1)

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
      assert_equal jobid, id
      job = MessagePack.unpack(serialized_job)
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
    Failer.enqueue('this can only end positively')

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
end
