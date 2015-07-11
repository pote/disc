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
  CreateGameGrid.enqueue('ligth_cycle')
  ```

4. Or enqueue them to be performed at some time in the future.

  ```ruby
  CreateGameGrid.enqueue_at(DateTime.new(2015, 12, 31), 'disc_arena')
  ```

5. Create a file that requires anything needed for your jobs to run

  ```ruby
# disc_init.rb
  require 'ohm'
  Dir['./jobs/**/*.rb'].each { |job| require job }
  ```

7. Run as many Disc Worker processes as you wish.

  ```bash
  $ QUEUES=urgent,default disc -r ./disc_init.rb
  ```

## Settings

Disc takes its configuration from environment variables.

| ENV Variable     |  Default Value   | Description
|:----------------:|:-----------------|:------------|
| QUEUES           | 'default'        | The list of queues that `Disc::Worker` will listen to, it can be a single queue name or a list of comma-separated queues |
| DISC_CONCURRENCY | '25'             | Amount of threads to spawn when Celluloid is available. |
| DISQUE_NODES     | 'localhost:7711' | This is the list of Disque servers to connect to, it can be a single node or a list of comma-separated nodes |
| DISQUE_AUTH      | ''               | Authorization credentials for Disque. |
| DISQUE_TIMEOUT   | '100'            | Time in milliseconds that the client will wait for the Disque server to acknowledge and replicate a job |
| DISQUE_CYCLE     | '1000'           | The client keeps track of which nodes are providing more jobs, after the amount of operations specified in cycle it tries to connect to the preferred node. |


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

## PowerUps

Disc workers can run just fine on their own, but if you're using
[Celluloid](https://github.com/celluloid/celluloid) you migth want Disc to take
advantage of it and spawn multiple worker threads per process, doing this is
trivial! Just require Celluloid before your init file:

```bash
$ QUEUES=urgent,default disc -r celluloid/current -r ./disc_init.rb
```

Whenever Disc detects that Celluloid is available it will use it to  spawn a
number of threads equal to the `DISC_CONCURRENCY` environment variable, or 25 by
default.
