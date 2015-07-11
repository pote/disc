# Disc

Disc allows you to easily leverage [antirez](http://antirez.com/)'s wonderful [Disque](https://github.com/antirez/disque) from your Ruby applications, filling the gap between your service objects and Disque.

## Usage

1.  Install the gem

```bash
$ gem install disc
```

2. Write your jobs

```ruby
requie 'disc'

class CreateGameGrid
  include Disque::Job
  disque_queue: :urgent

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
CreateGameGrid.enqueue('disc_arena', time: DateTime.new(2015, 12, 31))
```

5. Run as many Disc Worker processes as you wish.

```bash
$ DISQUE_QUEUES=urgent,default disc
```

You're done!
