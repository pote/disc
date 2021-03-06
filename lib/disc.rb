require 'date'
require 'disque'
require 'json'

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

  def self.[](disque_id)
    job_data = disque.call("SHOW", disque_id)
    return nil if job_data.nil?

    job_data = Hash[*job_data]
    job_data['arguments'] = Disc.deserialize(job_data['body'])['arguments']
    job_data['class'] = Disc.deserialize(job_data['body'])['class']

    job_data
  end

  ## Receives:
  #
  #   A string containing data serialized by `Disc.serialize`
  #
  ## Returns:
  #
  #   An array containing:
  #
  #     * An instance of the given job class
  #     * An array of arguments to pass to the job's `#perorm` class.
  #
  def self.load_job(serialized_job, disque_id = nil)
    begin
      job_data = Disc.deserialize(serialized_job)
    rescue => err
      raise Disc::NonParsableJobError.new(err)
    end

    begin
      job_class = Object.const_get(job_data['class'])
    rescue => err
      raise Disc::UnknownJobClassError.new(err)
    end

    begin
      job_instance = job_class.new
      job_instance.disque_id = disque_id
    rescue => err
      raise Disc::NonJobClassError.new(err)
    end

    return [job_instance, job_data['arguments']]
  end
end

require_relative 'disc/errors'
require_relative 'disc/job'
require_relative 'disc/version'
