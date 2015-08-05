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
    attr_reader :arguments,
                :disque,
                :disc_options

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

      def disc(options = {})
        @disc_options = options
      end

      def disc_options
        @disc_options ||= {}
      end

      def queue
        disc_options.fetch(:queue, 'default')
      end

      def enqueue(args = [], at: nil, queue: nil)
        disque.push(
          queue || self.queue,
          {
            class: self.name,
            arguments: Array(args)
          }.to_msgpack,
          Disc.disque_timeout,
          delay: at.nil? ? nil : (at.to_time.to_i - DateTime.now.to_time.to_i)
        )
      end
    end
  end
end
