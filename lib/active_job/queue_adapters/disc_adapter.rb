require 'date'
require 'msgpack'

module ActiveJob
  module QueueAdapters
    class DiscAdapter
      def enqueue(job)
        enqueue_at(job, nil)
      end

      def enqueue_at(job, timestamp)
        Disc.disque.push(
          job.queue_name,
          {
            class: job.class.name,
            arguments: job.arguments
          }.to_msgpack,
          Disc.disque_timeout,
          delay: timestamp.nil? ? nil : (timestamp.to_time.to_i - DateTime.now.to_time.to_i)
        )
      end
    end
  end
end
