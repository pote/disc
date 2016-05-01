require 'cutest'
require 'disc'

require_relative '../examples/echoer'

prepare do
  Disc.disque_timeout = 1 # 1ms so we don't wait at all.
  Disc.flush
end

scope do
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
end
