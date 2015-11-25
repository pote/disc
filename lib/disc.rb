require 'date'
require 'disque'
require 'msgpack'

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

  def self.flush
    Disc.disque.call('DEBUG', 'FLUSHALL')
  end

  def self.on_error(exception, job)
    $stderr.puts exception
  end

  class Worker
    attr_reader :disque,
                :queues,
                :timeout,
                :count

    def self.current
      @current ||= new
    end

    def self.run
      current.run
    end

    def self.stop
      current.stop
    end

    def initialize(options = {})
      @disque = options.fetch(:disque, Disc.disque)
      @queues = options.fetch(
        :queues,
        ENV.fetch('QUEUES', Disc.default_queue)
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

    def stop
      @stop = true
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

        break if @stop
      end
    ensure
      disque.quit
    end
  end

  module Job
    attr_accessor :disque_id,
                  :arguments

    def self.included(base)
      base.extend(ClassMethods)
    end

    def info
      return nil if disque_id.nil?

      Hash[*self.class.disque.call("SHOW", disque_id)]
    end

    def state
      info.fetch('state')
    end

    module ClassMethods
      def [](disque_id)
        job_data = disque.call("SHOW", disque_id)
        return nil if job_data.nil?

        job = self.new
        job_data = Hash[*job_data]

        job.disque_id = disque_id
        job.arguments = MessagePack.unpack(job_data.fetch('body')).fetch('arguments')

        return job
      end

      def disque
        defined?(@disque) ? @disque : Disc.disque
      end

      def disque=(disque)
        @disque = disque
      end

      def disc(queue: nil, **options)
        @queue = queue
        @disc_options = options
      end

      def disc_options
        @disc_options ||= {}
      end

      def queue
        @queue || Disc.default_queue
      end

      def enqueue(args = [], at: nil, queue: nil, **options)
        options = disc_options.merge(options).tap do |opt|
          opt[:delay] = at.to_time.to_i - DateTime.now.to_time.to_i unless at.nil?
        end

        disque_id = disque.push(
          queue || self.queue,
          {
            class: self.name,
            arguments: Array(args)
          }.to_msgpack,
          Disc.disque_timeout,
          options
        )

        return self[disque_id]
      end
    end
  end
end
