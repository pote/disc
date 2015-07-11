require 'date'
require 'disque'
require 'msgpack'

class Disc
  attr_reader :disque,
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
    include Celluloid if defined?(Celluloid)

    attr_reader :disque,
                :queues,
                :timeout,
                :count

    def self.run
      new.run
    end

    def initialize(options = {})
      @disque = options[:disque] || Disc.disque
      @count = (options[:count] || ENV.fetch('DISQUE_COUNT', '1')).to_i
      @timeout = (options[:timeout] || ENV.fetch('DISQUE_TIMEOUT', '2000')).to_i

      @queues = case
                when options[:queues].is_a?(Array)
                  options[:queues]
                when options[:queues].is_a?(String)
                  options[:queues].split(',')
                when options[:queues].nil?
                  ENV.fetch('QUEUES', 'default').split(',')
                else
                  raise 'Invalid Disque Queues'
                end

      self.run if options[:run]

      self
    end


    def run
      STDOUT.puts("Disc::Worker listening in #{queues}")
      loop do
        disque.fetch(
          from: queues,
          timeout: timeout,
          count: count
        ) do |serialized_job, _|
          job = MessagePack.unpack(serialized_job)
          klass = Object.const_get(job['class'])
          klass.new.perform(*job['arguments'])
        end
      end
    end
  end

  module Job
    attr_reader :arguments,
                :queue,
                :disque

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def disque
        defined?(@disque) ? @disque : Disc.disque
      end

      def disque=(disque)
        @disque = disque
      end

      def queue
        @queue ||= 'default'
      end

      def queue=(queue)
        @queue = queue
      end

      def enqueue(*args)
        disque.push(
          queue,
          {
            class: self.new.class.name,
            arguments: args
          }.to_msgpack,
          Disc.disque_timeout
        )
      end

      def enqueue_at(datetime, *args)
        disque.push(
          queue,
          args.to_msgpack,
          Disc.disque_timeout,
          delay: datetime && (datetime.to_time.to_i - DateTime.now.to_time.to_i)
        )
      end

      def disc(options = {})
        self.queue = options.fetch(:queue, 'default')
      end
    end
  end
end
