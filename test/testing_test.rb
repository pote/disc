# Yo dawg I put some testing in your testing so you can test while you test.

require 'disc'
require 'disc/testing'

require_relative '../examples/echoer'

prepare do
  Disc.disque_timeout = 1 # 1ms so we don't wait at all.
  Disc.flush
end

scope do
  test "testing mode should not enqueue jobs into Disque" do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])
    assert_equal 0, Disc.disque.call('QLEN', 'test')
    assert_equal 1, Disc.qlen('test')
  end

  test "testing mode enqueue jobs into an in-memory list by default" do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])
    assert_equal 1, Disc.queues['test'].count
  end
end
