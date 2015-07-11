require 'disque'
require 'msgpack'

class Disc
  attr_reader: :disque,
               :disque_timeout

  def self.disque
    @disque ||= Disque.new(
      ENV.fetch('DISQUE_NODES', 'localhost:7711'),
      auth: ENV.fetch('DISQUE_AUTH', nil),
      cycle: ENV.fetch('DISQUE_CYCLE', '1000').to_i
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

  class Worker
    attr_reader :disque,
                :queues,
                :timeout,
                :count

    def self.run
      new.run
    end

    def initialize(disque: nil , queues: nil, count: 1, timeout: nil)
      @disque = client || Disc.disque
      @count, @timeout = count, timeout
      @queues = case
                when queues.is_a?(Array)
                  queues
                when queues.is_a?(String)
                  queues.split(',')
                when queues.nil?
                 ENV.fetch('QUEUES', 'default').split(',')
                else
                 raise 'Invalid Disque Queues'
                end

      self
    end


    def run
      loop do
        disque.fetch(
          from: queues,
          timeout: timeout,
          count: count
        ) do |serialized_job, _|
          job = Disc::Job.deserialize(MessagePack.unpack(serialized_job))
          job.perform(job['arguments'])
        end
      end
    end
  end

  class Job
    attr_reader :arguments,
                :queue

    def self.disque=(disque)
      @disque = disque
    end

    def self.disque
      defined?(@disque) ? @disque : Disc.disque
    end

    def self.queue(name = 'default')
      @queue ||= name
    end

    def self.enqueue(*args, time: nil)
      job = new(args)

      disque.push(
        job.queue,
        job.serializable.to_msgpack,
        Disc.disque_timeout,
        delay: (time.to_i - Time.current.to_i)
      )
    end

    def self.deserialize(serialized_job)
    end

    def initialize(arguments)
      @arguments = arguments
    end

    def serializable
      {
        class:      self.class.name,
        arguments:  self.arguments
      }
    end
  end
end
