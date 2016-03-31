# Advanced Connection

AdvancedConnection is a rails (~> 4.1) plugin that provides advanced management features for Rails' ActiveRecord connection pool. Features include:
  - Idle Connection Manager
  - Connection-less Code Blocks
  - Statement Pooling (**EXPERIMENTAL**)

### Version

[![Gem Version](https://badge.fury.io/rb/advanced_connection.svg)](https://badge.fury.io/rb/advanced_connection)

### Installation

You need Gulp installed globally:

```sh
$ gem install advanced_connection
```

or in your Gemfile, add:

```ruby
gem 'advanced_connection', '~> 0.5.6'
```

Then generate your `AdvancedConnection` configuration by executing:

```sh
bundle exec rails generate advanced_connection:install
```

### Usage and Configuration

#### Idle Connection Manager

Enabling this will enable idle connection management. This allows you to specify settings
to enable automatic warmup of connections on rails startup, min/max idle connections and
idle connection culling.

```text
  enable_idle_connection_manager = true | false
```

Pool queue type determines both how free connections will be checkout out of the pool, as well as how idle connections will be culled. The options are:

<dl>
  <dt><strong>:fifo</strong></dt>
    <dd>All connections will have an equal opportunity to be used and culled (default)</dd>
    <br />
  <dt><strong>:lifo, :stack</strong></dt>
    <dd>More frequently used connections will be reused, leaving less frequently used connections to be culled</dd>
    <br />
  <dt><strong>:prefer_older</strong></dt>
    <dd>Longer lived connections will tend to stick around longer, with younger connections being culled</dd>
    <br />
  <dt><strong>:prefer_younger</strong></dt>
    <dd>Younger lived connections will tend to stick around longer, with older connections being culled</dd>
</dl>

```text
  connection_pool_queue_type = :fifo | :lifo | :stack | :prefer_older | :prefer_younger
```

How many connections to prestart on initial startup of rails. This can help to reduce the time it takes a restarted production node to start responding again.
```text
  warmup_connections = integer | false
```

Minimum number of connection to keep idle. If, during the idle check, you have fewer than this many connections idle, then a number of new connections will be created up to this this number.
```text
  min_idle_connections = integer
```

Maximum number of connections that can remain idle without being culled. If you have
more idle conections than this, only the difference between the total idle and this
maximum will be culled.
```text
  max_idle_connections = integer | Float::INFINITY
```

How long (in seconds) a connection can remain idle before being culled
```text
  max_idle_time = integer
```

How many seconds between idle checks (defaults to max_idle_time)
```text
  idle_check_interval = integer
```

#### Connection-less Code Blocks

 Enabling this will add a new method to ActiveRecord::Base that allows you to mark a block of code as not requiring a connection. This can be useful in reducing pressure on the pool, especially when you have sections of code that make potentially long-lived external requests. E.g.,

 ```ruby
 require 'open-uri'
 results = ActiveRecord::Base.without_connection do
   open('http://some-slow-site.com/api/')
 end
 ```

During the call to the remote site, the db connection is checked in and subsequently checked back out once the block finishes. To enable this feature, uncomment the following:

```ruby
  enable_without_connection = true | false
```

<div style="color: rgb(201, 79, 79); padding-bottom: 1em;"> WARNING: this feature cannot be enabled with Statement Pooling.</div>

Additionally, you can hook into the checkin / checkout lifecycle by way of callbacks. This can be extremely useful when employing something like [`Apartment`][apt] to manage switching between tenants.

```ruby
without_connection_callbacks = {
  # runs right before the connection is checked back into the pool
  before:  ->() { },
  around:  ->(&block) {
    tenant = Apartment::Tenant.current
    block.call
    Apartment::Tenant.switch(tenant)
  },
  # runs right after the connection is checked back out of the pool
  after:  ->() { }
}
```

#### Statement Pooling

### Todos

 - Finish development of Statement Pooling
 - Write Tests
 - Add Code Comments

License
----

MIT


[//]: # (references)
   [apt]: <https://github.com/influitive/apartment/>
