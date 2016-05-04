# Disc [![Build Status](https://travis-ci.org/pote/disc.svg?branch=master)](https://travis-ci.org/pote/disc)

Disc fills the gap between your Ruby service objects and [antirez](http://antirez.com/)'s wonderful [Disque](https://github.com/antirez/disque) backend.

<a href="https://www.flickr.com/photos/noodlefish/5321412234" target="blank_">
![Disc Wars!](https://cloud.githubusercontent.com/assets/437/8634016/b63ee0f8-27e6-11e5-9a78-51921bd32c88.jpg)
</a>

## Basic Usage

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

    def self.perform(type)
      # perform rather lengthy operations here.
    end
  end
  ```

3. Enqueue them to perform them asynchronously

  ```ruby
  CreateGameGrid.enqueue('light_cycle')
  ```


4. Create a file that requires anything needed for your jobs to run

  ```ruby
# disc_init.rb
  # Require here anything that your application needs to run,
  # like ORMs and your models, database configuration, etc.
  Dir['./jobs/**/*.rb'].each { |job| require job }
  ```

5. Run as many Disc Worker processes as you wish, requiring your `disc_init.rb` file

  ```bash
  $ QUEUES=urgent,default disc -r ./disc_init.rb
  ```

4. Or enqueue them to be performed at some time in the future, or on a queue other than it's default.

  ```ruby
  CreateGameGrid.enqueue(
    'disc_arena',
    at: DateTime.new(2020, 12, 31),
    queue: 'not_so_important'
  )
  ```

## Disc Jobs

`Disc::Job` is a module you can include in your Ruby classes, this allows a Disc worker process to execute the code in them by adding a class method (`#enqueue`) with the following signature:

```Ruby
def enqueue(arguments, at: nil, queue: nil, **options)
end
```

Signature documentation follows:

```ruby
## Disc's `#enqueue` is the main user-facing method of a Disc job, it
#  enqueues a job with a given set of arguments in Disque, so it can be
#  picked up by a Disc worker process.
#
## Parameters:
#
## `arguments`  - an optional array of arguments with which to execute
#                 the job's `self.perform` method.
#
# `at`          - an optional named parameter specifying a moment in the
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
#  `Array()` will be used internally to preserve the array structure.
#
## The `arguments` parameter is serialized for storage using `Disc.serialize`
#  and Disc workers picking it up use `Disc.deserialize` on it, both methods
#  use standard library json but can be overriden by the user
#
```

You can see [Disque's ADDJOB documentation](https://github.com/antirez/disque#addjob-queue_name-job-ms-timeout-replicate-count-delay-sec-retry-sec-ttl-sec-maxlen-count-async) for more details

When a Disc worker process is assigned a job, it will create a new intance of the job's class and execute the `self.perform` method with whatever arguments were previously passed to `#enqueue`.

Example:

```ruby
class ComplexJob
  include Disc::Job
  disc queue: 'urgent'

  def self.perform(first_parameter, second_parameter)
    # do things...
  end
end


ComplexJob.enqueue(['first argument', { second: 'argument' }])
```

### Job Serialization

Job information (their arguments, and class) need to be serialized in order to be stored
in Disque, to this end Disc uses the `Disc.serialize` and `Disc.deserialize` methods.

By default, these methods use by default the Ruby standard library json implementation in order to serialize and deserialize job data, this has a few implications:

1. Arguments passed to a job's `#enqueue` method need to be serializable by `Disc.serialize` and parsed back by `Disc.deserialize`, so by default you can't pass complex Ruby objects like a `user` model, instead, pass `user.id`, and use that from your job code.

2. You can override `Disc.serialize` and `Disc.deserialize` to use a different JSON implementation, or MessagePack, or whatever else you wish.


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

### Job Definition

The error handler function gets the data of the current job as a Hash, that has the following schema.

|               |                                                       |
|:-------------:|:------------------------------------------------------|
| `'class'`     | (String) The Job class.                               |
| `'arguments'` | (Array) The arguments passed to perform.              |
| `'queue'`     | (String) The queue from which this job was picked up. |
| `'disque_id'` | (String) Disque's job ID.                             |


## Testing modes

Disc includes a testing mode, so you can run your test suite without a need to run a Disque server.

### Enqueue mode

By default, Disc places your jobs in an in-memory hash, with each queue being a key in the hash and values being an array.

```ruby
require 'disc'
require 'disc/testing'

require_relative 'examples/returner'
Disc.enqueue! #=> This is the default mode for disc/testing so you don't need to specify it,
              #   you can use this method to go back to the enqueue mode if you switch it.


Returner.enqueue('test argument')

Disc.queues
#=> {"default"=>[{:arguments=>["test argument"], :class=>"Returner", :options=>{}}]}

Returner.enqueue('another test')
#=> => {"default"=>[{:arguments=>["test argument"], :class=>"Returner", :options=>{}}, {:arguments=>["another test"], :class=>"Returner", :options=>{}}]}


```

You can still flush the queues just as you would running on regular mode.

```ruby
Disc.flush

Disc.queues
#=> {}
```

### Inline mode

You also have the option for Disc to execute jobs immediately when `#enqueue` is called.

```ruby
require 'disc'
require 'disc/testing'

require_relative 'examples/returner'
Disc.inline!

Returner.enqueue('test argument')
#=> 'test argument'
```

## [Optional] Celluloid integration

Disc workers run just fine on their own, but if you happen to be using
[Celluloid](https://github.com/celluloid/celluloid) you might want Disc to take
advantage of it and spawn multiple worker threads per process, doing this is
trivial! Just require Celluloid before your init file:

```bash
$ QUEUES=urgent,default disc -r celluloid/current -r ./disc_init.rb
```

Whenever Disc detects that Celluloid is available it will use it to  spawn a
number of threads equal to the `DISC_CONCURRENCY` environment variable, or 25 by
default.

## [Optional] Rails and ActiveJob integration

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

  def self.perform(*args)
    # Try to take over The Grid here...
  end
end

# disc_init.rb
require ::File.expand_path('../config/environment', __FILE__)

# Wherever you want
CluJob.perform_later(a_bunch_of_arguments)
```

Disc is run in the exact same way, for this example it'd be:

```bash
$ QUEUES=urgent disc -r ./disc_init.rb
```

## Similar Projects

If you want to use Disque but Disc isn't cutting it for you then you should take a look at [Havanna](https://github.com/djanowski/havanna), a project by my friend [@djanowski](https://twitter.com/djanowski).

## License

The code is released under an MIT license. See the [LICENSE](./LICENSE) file for
more information.

## Acknowledgements

* To [@foca](https://github.com/foca) for helping me ship a quality thing and putting up with my constant whining.
* To [@antirez](https://github.com/antirez) for Redis, Disque, and his refreshing way of programming wonderful tools.
* To [@soveran](https://github.com/soveran) for pushing me to work on this and publishing gems that keep me enjoying ruby.
* To [all contributors](https://github.com/pote/disc/graphs/contributors)

## Sponsorship

This open source tool is proudly sponsored by [13Floor](http://13Floor.org)

![13Floor](./13Floor-circulo-1.png)
