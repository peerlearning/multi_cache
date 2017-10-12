# MultiCache

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'multi_cache'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install multi_cache

## Usage

After installing, the gem:

 Create config/initializers/init_multi_cache.rb
 and add the lines

     MultiCache.configure do |config|
       config.redis_instance "<redis-instance>"
     end

   where <redis-instance> is the Redis::Namespace object to be used by 
   MultiCache for caching
   Please ensure that the <redis-instance> is wrapped in quotes
   

All models where you want to use MultiCache must:
 
 [mandatory]   Define a CLASS method
               MULTI_CACHE_PREFIXES
                 that returns an array of allowed cache prefixes used by
                 the class   
 
 [mandatory]   Define a CLASS method 
               GEN_CACHE_CONTENT(ID_OR_OBJ, CACHE_PREFIX)
                 that generates a hash that will be cached
                 ID_OR_OBJ is a hash that contains 
                   {:id => obj_id, :obj => actual_obj_if_available}
               CACHE_PREFIX is an optional string that can be used to 
                 distinguish between different cached info for the same
                 object.

 [optional]    Define a CLASS method 
               PARSE_CACHE_CONTENT(CONTENT, CACHE_PREFIX)
                 that parses the cached content once it is read from 
                 redis. Sometimes some JSON.parses are required. If not
                 defined, the default method is called (which simply returns
                 the cached value as-is)

## Development

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/peerlearning/multi_cache. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

