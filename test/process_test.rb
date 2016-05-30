require 'cutest'
require 'disc'
require 'pty'
require 'timeout'

require_relative '../examples/echoer'
require_relative '../examples/failer'
require_relative '../examples/identifier'

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

  test 'Disc.on_error will catch unhandled exceptions and keep disc alive' do
    failer = Failer.enqueue('this can only end positively')

    run('QUEUES=test ruby -Ilib bin/disc -r ./examples/failer') do |cout, pid|
      output = Timeout.timeout(1) { cout.take(5) }
      assert output.grep(/<insert error reporting here>/).any?
      assert output.grep(/this can only end positively/).any?
      assert output.grep(/Failer/).any?

      assert is_running?(pid)
      assert_equal 0, Disc.qlen(Failer.queue)
    end
  end

  test 'jobs are executed' do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])

    run('QUEUES=test ruby -Ilib bin/disc -r ./examples/echoer') do |cout, pid|
      output = Timeout.timeout(1) { cout.take(3) }
      assert output.grep(/First: one argument, Second: {"random"=>"data"}, Third: 3/).any?
      assert_equal 0, Disc.qlen(Echoer.queue)
    end
  end

  test 'running jobs have access to their Disque job ID' do
    disque_id = Identifier.enqueue

    run('QUEUES=test ruby -Ilib bin/disc -r ./examples/identifier') do |cout, pid|
      output = Timeout.timeout(1) { cout.take(3) }
      assert output.grep(/Working with Disque ID: #{ disque_id }/).any?

      assert_equal 0, Disc.qlen(Identifier.queue)
    end
  end
end
