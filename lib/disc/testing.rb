module Disc::Job::ClassMethods
  def mocked_queue
    @_mocked_queue ||= []
  end

  def enqueue(args = [], at: nil, queue: nil, **options)
    mocked_queue << { args: args, at: at, options: options }
  end
end
