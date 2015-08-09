require 'date'
require 'disque'
require 'msgpack'

require_relative 'disc/version'

class Disc
  attr_reader :disque,
    :disque_timeout

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

  def self.on_error(exception, job)
    $stderr.puts exception
  end

  class Worker
    attr_reader :disque,
                :queues,
                :timeout,
                :count

    def self.run
      new.run
    end

    def initialize(options = {})
      @disque = options.fetch(:disque, Disc.disque)
      @queues = options.fetch(
        :queues,
        ENV.fetch('QUEUES', 'default')
      ).split(',')
      @count = Integer(
        options.fetch(
          :count,
          ENV.fetch('DISQUE_COUNT', '1')
        )
      )
      @timeout = Integer(
        options.fetch(
          :timeout,
          ENV.fetch('DISQUE_TIMEOUT', '2000')
        )
      )

      self.run if options[:run]
      self
    end

    def run
      $stdout.puts("Disc::Worker listening in #{queues}")
      loop do
        jobs = disque.fetch(from: queues, timeout: timeout, count: count)
        Array(jobs).each do |queue, msgid, serialized_job|
          begin
            job = MessagePack.unpack(serialized_job)
            instance = Object.const_get(job['class']).new
            instance.perform(*job['arguments'])
            disque.call('ACKJOB', msgid)
          rescue => err
            Disc.on_error(err, job.update('id' => msgid, 'queue' => queue))
          end
        end
      end
    end
  end

  module Job
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def queue
        @queue ||= Disc.default_queue
      end
      attr_writer :queue

      def disque
        @disque ||= Disc.disque
      end
      attr_writer :disque

      def disque_timeout
        @disque_timeout ||= Disc.disque_timeout
      end
      attr_writer :disque_timeout

      def disque_options
        @disque_options ||= {}
      end
      attr_writer :disque_options

      def disc(options = {})
        warn "[DEPRECATED] `disc_options(queue: 'foo')` is deprecated. Use `self.queue = 'foo'."
        self.queue = options.fetch(:queue, self.queue)
      end

      def enqueue(args = [], at: nil, queue: nil, **disque_options)
        options = self.disque_options.merge(disque_options)
        unless at.nil?
          options[:delay] = at.to_time.to_i - DateTime.now.to_time.to_i
        end

        disque.push(
          queue || self.queue,
          { class: self.name, arguments: Array(args) }.to_msgpack,
          disque_timeout,
          options
        )
      end
    end
  end
end
