require 'cutest'
require 'disc'

require_relative '../examples/echoer'

prepare do
  Disc.disque_timeout = 1 # 1ms so we don't wait at all.
  Disc.flush
end

scope do
  test 'Disc should be able to communicate with Disque' do
    assert !Disc.disque.nil?

    assert_equal 'PONG', Disc.disque.call('PING')
  end

  test 'we get easy access to the job via the job id with Disc[job_id]' do
    job_id = Echoer.enqueue(['one argument', { random: 'data' }, 3])

    job_data = Disc[job_id]

    assert_equal 'Echoer', job_data['class']
    assert_equal 'queued', job_data['state']
    assert_equal 3, job_data['arguments'].count
    assert_equal 'one argument', job_data['arguments'].first
  end

  test 'we can query the length of a given queue with Disc.qlen' do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])

    assert_equal 1, Disc.qlen(Echoer.queue)
  end

  test 'Disc.flush deletes everything in the queue' do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])
    Disc.flush

    assert_equal 0, Disc.qlen(Echoer.queue)
  end

  test 'Disc.load_job returns a job instance and arguments' do
    serialized_job = Disc.serialize(
      { class: 'Echoer', arguments: ['one argument', { random: 'data' }, 3] }
    )

    job_instance, arguments = Disc.load_job(serialized_job)

    assert job_instance.is_a?(Echoer)
    assert arguments.is_a?(Array)
    assert_equal 3, arguments.count
    assert_equal 'one argument', arguments.first
  end

  test 'Disc.load_job raises appropriate errors ' do
    begin
      job_instance, arguments = Disc.load_job('gibberish')
      assert_equal 'Should not reach this point', false
    rescue => err
      assert err.is_a?(Disc::NonParsableJobError)
    end
  end
end
