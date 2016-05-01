module Disc::Job
  attr_accessor :disque_id,
                :arguments

  def self.included(base)
    base.extend(ClassMethods)
  end

  #def info
  #  return nil if disque_id.nil?

  #  Hash[*self.class.disque.call("SHOW", disque_id)]
  #end

  #def state
  #  current_info = info
  #  return nil if info.nil?

  #  info.fetch('state')
  #end

  module ClassMethods
    def [](disque_id)
      job_data = disque.call("SHOW", disque_id)
      return nil if job_data.nil?

      job = self.new
      job_data = Hash[*job_data]

      job.disque_id = disque_id
      job.arguments = Disc.deserialize(job_data.fetch('body')).fetch('arguments')

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

    def perform(arguments)
      self.new.perform(*arguments)
    end

    ## Disc's `#enqueue` is the main user-facing method of a Disc job, it
    #  enqueues a job with a given set of arguments in Disque, so it can be
    #  picked up by a Disc worker process.
    #
    ## Parameters:
    #
    ## `arguments`  - an optional array of arguments with which to execute
    #                 the job's #perform method.
    #
    ## `at`         - an optional named parameter specifying a moment in the
    #                 future in which to run the job, must respond to
    #                 `#to_time`.
    #
    ## `queue`      - an optional named parameter specifying the name of the
    #                 queue in which to store the job, defaults to the class
    #                 Disc queue or to 'default' if no Disc queue is specified
    #                 in the class.
    #
    ##  `**options` - an optional hash of options to forward internally to
    #                 [disque-rb](https://github.com/soveran/disque-rb)'s
    #                 `#push` method, valid options are:
    #
    ##  `replicate: <count>`  - specifies the number of nodes the job should
    #                           be replicated to.
    #
    ### `delay: <sec>`        - specifies a delay time in seconds for the job
    #                           to be delivered to a Disc worker, it is ignored
    #                           if using the `at` parameter.
    #
    ### `ttl: <sec>`          - specifies the job's time to live in seconds:
    #                           after this time, the job is deleted even if
    #                           it was not successfully delivered. If not
    #                           specified, the default TTL is one day.
    #
    ### `maxlen: <count>`     - specifies that if there are already <count>
    #                           messages queued for the specified queue name,
    #                           the message is refused.
    #
    ### `async: true`         - asks the server to let the command return ASAP
    #                           and replicate the job to other nodes in the background.
    #
    #
    ### CAVEATS
    #
    ## For convenience, any object can be passed as the `arguments` parameter,
    #  `Array.wrap` will be used internally to preserve the array structure.
    #
    ## The `arguments` parameter is serialized for storage using `Disc.serialize`
    #  and Disc workers picking it up use `Disc.deserialize` on it, both methods
    #  use standard library json but can be overriden by the user
    #
    def enqueue(args = [], at: nil, queue: nil, **options)
      options = disc_options.merge(options).tap do |opt|
        opt[:delay] = at.to_time.to_i - DateTime.now.to_time.to_i unless at.nil?
      end

      disque.push(
        queue || self.queue,
        Disc.serialize({
          class: self.name,
          arguments: Array(args)
        }),
        Disc.disque_timeout,
        options
      )
    end
  end
end
