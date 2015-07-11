# Disc

Disc fills the gap between your Ruby service objects and [antirez](http://antirez.com/)'s wonderful [Disque](https://github.com/antirez/disque) backend.

<a href=https://www.flickr.com/photos/noodlefish/5321412234/in/photolist-91LsrP-4nrahM-91PzfG-92HS1v-8ApwqD-q5sH-dM6d74-52zUMi-cJ2iVN-cJ1Egs-hcQpne-9d9RyF-9dWnVK-b5EGYP-arSsBd-6JgG1Y-qJoCkE-88Vp8g-92M3HC-9CL8KH-97eCsN-8HtoUt-2PkxTh-993Jiy-ad7xjp-a3MKZU-8Hwxgu-raHDW-993JAC-AAEa-b9LKDR-8nW7mM-qJsPN4-6Bo8Fw-qJoFjL-9CEg7J-9RDVRc-rZWuCt-9751Cf-hZyWZw-gPqXZm-8KiTxg-dpoXjb-dpoNjB-93hj1h-9sX9ii-8KiJvr-LXLH5-dhe92T-3GQgs6" target="blank_">
![Disc Wars!](./disc-wars.jpg)
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
  Dir.glob('jobs/**/*.rb') { |f| require_relative f }
  ```

6. Set your require file

  ```bash
  $ export DISC_REQUIRE='./disc_init.rb'
  ```

7. Run as many Disc Worker processes as you wish.

  ```bash
  $ QUEUES=urgent,default disc
  ```

## Settings

Disc takes its configuration from environment variables.

| ENV Variable     |  Default Value   | Description
|:----------------:|:-----------------|:------------|
| DISC_REQUIRE     | null             | Ruby file that will be required by the worker processes, it should load all Disc::Job classes on your application and whatever else is needed to run them.
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

Disc workers can run just fine on their own, but if you're using [Celluloid](https://github.com/celluloid/celluloid) you migth want Disc to take advantage of it and spawn multiple worker threads per process, doing this is trivial! Just require Celluloid in your `DISC_REQUIRE` file.

```ruby
# disq_init.rb
require 'celluloid'
```

Whenever Disc detects that Celluloid is available it will use it to  spawn a number of threads equal to the `DISC_CONCURRENCY` environment variable, or 25 by default.
