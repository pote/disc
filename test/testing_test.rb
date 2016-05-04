# Yo dawg I put some testing in your testing so you can test while you test.

require 'disc'
require 'disc/testing'

require_relative '../examples/echoer'
require_relative '../examples/returner'

prepare do
  Disc.disque_timeout = 1 # 1ms so we don't wait at all.
  Disc.enqueue!
  Disc.flush
end

scope do
  test "testing mode should not enqueue jobs into Disque" do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])
    assert_equal 0, Disc.disque.call('QLEN', 'test')
    assert_equal 1, Disc.qlen('test')

    # Flush should still work though
    Disc.flush
    assert_equal 0, Disc.qlen('test')
  end

  test "testing mode enqueue jobs into an in-memory list by default" do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])

    assert_equal 1, Disc.queues['test'].count
    assert Disc.queues['test'].first.has_key?(:arguments)
    assert_equal 3, Disc.queues['test'].first[:arguments].count
    assert_equal 'one argument', Disc.queues['test'].first[:arguments].first
    assert_equal 'Echoer', Disc.queues['test'].first[:class]
  end

  test "testing mode enqueue jobs into an in-memory list by default" do
    Echoer.enqueue(['one argument', { random: 'data' }, 3])
    assert_equal 'one argument', Disc.queues['test'].first[:arguments].first
  end

  test "ability to run jobs inline" do
    Disc.inline!
    assert_equal 'this is an argument',  Returner.enqueue('this is an argument')
  end
end
