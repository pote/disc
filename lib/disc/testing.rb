class Disc
  def self.queues
    @queues ||= {}
  end

  def self.testing_mode
    @testing_mode ||= 'testing'
  end

  def sel.testing!
    @testing_mode = 'testing'
  end

  def self.inline!
    @testing_mode = 'inline'
  end

  def self.flush
    @queues = {}
  end

  def self.qlen(queue)
    return 0 if Disc.queues[queue].nil?

    Disc.queues[queue].length
  end

  def self.enqueue(klass, arguments, at: nil, queue: nil, **options)
    if queues[queue].empty?
      queues[queue] = [{arguents: arguments, class: klass, options: options}]
    else
      queues[queue] << {arguents: arguments, class: klass, options: options}
    end
  end
end

module Disc::Job::ClassMethods
  def enqueue(args = [], at: nil, queue: nil, **options)
    case Disc.testing_mode
    when 'testing'
      Disc.enqueue(self.class.name, queue || self.queue, args, at: at, options)
    when 'inline'
      self.new.perform(*args)
    else
      raise "Unknown Disc testing mode, this shouldn't happen"
    end
  end
end
