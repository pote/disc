require 'date'
require 'msgpack'
require 'disc/worker'

module ActiveJob
  module QueueAdapters
    class DiscAdapter
      def self.enqueue(job)
        enqueue_at(job, nil)
      end

      def self.enqueue_at(job, timestamp)
        Disc.disque.push(
          job.queue_name,
          Disc.serialize({
            class: job.class.name,
            arguments: job.arguments
          }),
          Disc.disque_timeout,
          delay: timestamp.nil? ? nil : (timestamp.to_time.to_i - DateTime.now.to_time.to_i)
        )
      end
    end
  end
end
