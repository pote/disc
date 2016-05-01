require 'date'
require 'disque'
require 'json'

require_relative 'disc/version'

class Disc
  def self.disque
    @disque ||= Disque.new(
      ENV.fetch('DISQUE_NODES', 'localhost:7711'),
      auth: ENV.fetch('DISQUE_AUTH', nil),
      cycle: Integer(ENV.fetch('DISQUE_CYCLE', '1000'))
    )
  end

  def self.disque=(disque)
    @disque = disque
  end

  def self.disque_timeout
    @disque_timeout ||= 100
  end

  def self.disque_timeout=(timeout)
    @disque_timeout = timeout
  end

  def self.default_queue
    @default_queue ||= 'default'
  end

  def self.default_queue=(queue)
    @default_queue = queue
  end

  def self.qlen(queue)
    disque.call('QLEN', queue)
  end

  def self.flush
    Disc.disque.call('DEBUG', 'FLUSHALL')
  end

  def self.on_error(exception, job)
    $stderr.puts exception
  end

  def self.serialize(args)
    JSON.dump(args)
  end

  def self.deserialize(data)
    JSON.parse(data)
  end
end

require_relative 'disc/job'
