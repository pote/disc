require 'disc'


class Disc::Worker
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
          job_class, arguments = Disc.load_job(serialized_job)
          job_class.perform(*arguments)
          disque.call('ACKJOB', msgid)
          $stdout.puts("Completed #{ job_class.name } id #{ msgid }")
        rescue => err
          Disc.on_error(err, {
            disque_id: msgid,
            queue: queue,
            class: defined?(job_class) ? job_class.name : '',
            arguments: defined?(arguments) ? arguments : []
          })
        end
      end

      break if @stop
    end
  ensure
    disque.quit
  end
end
