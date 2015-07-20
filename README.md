# Disc

Disc fills the gap between your Ruby service objects and [antirez](http://antirez.com/)'s wonderful [Disque](https://github.com/antirez/disque) backend.

<a href=https://www.flickr.com/photos/noodlefish/5321412234" target="blank_">
![Disc Wars!](https://cloud.githubusercontent.com/assets/437/8634016/b63ee0f8-27e6-11e5-9a78-51921bd32c88.jpg)
</a>

## Usage

1.  Install the gem

  ```bash
  $ gem install disc
  ```

2. Write your jobs

  ```ruby
  require 'disc'

  class CreateGameGrid
    include Disc::Job
    disc queue: 'urgent'

    def perform(type)
      # perform rather lengthy operations here.
    end
  end
  ```

3. Enqueue them to perform them asynchronously

  ```ruby
  CreateGameGrid.enqueue('light_cycle')
  ```

4. Or enqueue them to be performed at some time in the future, or on a queue other than it's default.

  ```ruby
  CreateGameGrid.enqueue(
    'disc_arena',
    at: DateTime.new(2015, 12, 31),
    queue: 'not_so_important'
  )
  ```

5. Create a file that requires anything needed for your jobs to run

  ```ruby
# disc_init.rb
  require 'ohm'
  Dir['./jobs/**/*.rb'].each { |job| require job }
  ```

6. Run as many Disc Worker processes as you wish, requiring your `disc_init.rb` file

  ```bash
  $ QUEUES=urgent,default disc -r ./disc_init.rb
  ```

## Settings

Disc takes its configuration from environment variables.

| ENV Variable       |  Default Value   | Description
|:------------------:|:-----------------|:------------|
| `QUEUES`           | 'default'        | The list of queues that `Disc::Worker` will listen to, it can be a single queue name or a list of comma-separated queues |
| `DISC_CONCURRENCY` | '25'             | Amount of threads to spawn when Celluloid is available. |
| `DISQUE_NODES`     | 'localhost:7711' | This is the list of Disque servers to connect to, it can be a single node or a list of comma-separated nodes |
| `DISQUE_AUTH`      | ''               | Authorization credentials for Disque. |
| `DISQUE_TIMEOUT`   | '100'            | Time in milliseconds that the client will wait for the Disque server to acknowledge and replicate a job |
| `DISQUE_CYCLE`     | '1000'           | The client keeps track of which nodes are providing more jobs, after the amount of operations specified in cycle it tries to connect to the preferred node. |

## Error handling

When a job raises an exception, `Disc.on_error` is invoked with the error and
the job data. By default, this method prints the error to standard error, but
you can override it to report the error to your favorite error aggregator.

``` ruby
# On disc_init.rb
def Disc.on_error(exception, job)
  # ... report the error
end

Dir["./jobs/**/*.rb"].each { |job| require job }
```

## Job Definition

The error handler function gets the data of the current job as a Hash, that has the following schema.

|               |                                                       |
|:-------------:|:------------------------------------------------------|
| `'class'`     | (String) The Job class.                               |
| `'arguments'` | (Array) The arguments passed to perform.              |
| `'queue'`     | (String) The queue from which this job was picked up. |
| `'id'`        | (String) Disque's job ID.                             |

## Celluloid PowerUps

Disc workers can run just fine on their own, but if you happen to be using
[Celluloid](https://github.com/celluloid/celluloid) you might want Disc to take
advantage of it and spawn multiple worker threads per process, doing this is
trivial! Just require Celluloid before your init file:

```bash
$ QUEUES=urgent,default disc -r celluloid/current -r ./disc_init.rb
```

Whenever Disc detects that Celluloid is available it will use it to  spawn a
number of threads equal to the `DISC_CONCURRENCY` environment variable, or 25 by
default.

## Rails and ActiveJob integration

You can use Disc easily in Rails without any more hassle, but if you'd like to use it via [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) you can use the adapter included in this gem.

```ruby
# Gemfile
gem 'disc'

# config/application.rb
module YourApp
  class Application < Rails::Application
    require 'active_job/queue_adapters/disc_adapter'
    config.active_job.queue_adapter = :disc
  end
end

# app/jobs/clu_job.rb

class CluJob < ActiveJob::Base
  queue_as :urgent

  def perform(*args)
    # Try to take over The Grid here...
  end
end

# Wherever you want
CluJob.perform_later(a_bunch_of_arguments)
```

As always, make sure your `disc_init.rb` file requires the necessary jobs and you'll be good to go!


## A note on stability

The version of Disque at the time of this writing is `0.0.1`. It is a wonderful project, I know of people running it in production and I expect it will only get better and better with time, but please do not expect Disc to be more production ready than Disque is.

## License

The code is released under an MIT license. See the [LICENSE](./LICENSE) file for
more information.

## Acknowledgements

* To [@godfoca](https://github.com/godfoca) for helping me ship a quality thing and putting up with my constant whining.
* To [@antirez](https://github,com/antirez) for Redis, Disque, and his refreshing way of programming wonderful tools.
* To [@soveran](https://github.com/soveran) for pushing me to work on this and publishing gems that keep me enjoying ruby.
* To [all contributors](https://github.com/pote/disc/graphs/contributors)
