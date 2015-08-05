require 'cutest'
require 'disc'
require 'msgpack'
require 'pty'

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
  Disc.disque.call('DEBUG', 'FLUSHALL')
end

scope do
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
    jobid = Echoer.enqueue(['one argument', { random: 'data' }, 3], at: Time.now + 3)

    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 1
    jobs = Array(Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1))
    assert jobs.empty?

    sleep 2
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
    begin
      Echoer.enqueue(['one argument', { random: 'data' }, 3])

      cout, _, pid = PTY.spawn(
        'QUEUES=test,default ruby -Ilib bin/disc -r ./examples/echoer'
      )
      sleep 0.5

      jobs = Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1)
      assert jobs.nil?

      matched = false
      counter = 0
      while !matched && counter < 3
        counter += 1
        matched = cout.gets.match(/First: one argument, Second: {"random"=>"data"}, Third: 3/)
      end

      assert matched
    ensure
      Process.kill("KILL", pid)
    end
  end

  test 'Disc.on_error will catch unhandled exceptions and keep disc alive' do
    begin
      Failer.enqueue('this can only end positively')

      cout, _, pid = PTY.spawn(
        'QUEUES=test ruby -Ilib bin/disc -r ./examples/failer'
      )
      sleep 0.5

      jobs = Disc.disque.fetch(from: ['test'], timeout: Disc.disque_timeout, count: 1)
      assert jobs.nil?

      counter = 0
      tasks = {
        reported_error: false,
        printed_message: false,
        printed_job: false
      }

      while tasks.values.include?(false) && counter < 5
        counter += 1
        output = cout.gets

        tasks[:reported_error] = true   if output.match(/<insert error reporting here>/)
        tasks[:printed_message] = true  if output.match(/this can only end positively/)
        tasks[:printed_job] = true      if output.match(/Failer/)
      end

      assert !tasks.values.include?(false)

      begin
        Process.getpgid(pid)
        assert true
      rescue Errno::ESRCH
        assert false
      end
    ensure
      Process.kill("KILL", pid)
    end
  end
end
