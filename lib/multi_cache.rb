require "multi_cache/version"

module MultiCache
  extend ActiveSupport::Concern

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
  # 
  # After installation:
  #
  #   Create config/initializers/init_multi_cache.rb
  #   and add the lines
  #
  #       MultiCache.configure do |config|
  #         config.redis_instance "<redis-instance>"
  #       end
  #
  #     where <redis-instance> is the Redis::Namespace object to be used by 
  #     MultiCache for caching
  #     Please ensure that the <redis-instance> is wrapped in quotes
  #     
  #
  # All models where you want to use MultiCache must:
  #   
  #   [mandatory]   Define a CLASS method
  #                 MULTI_CACHE_PREFIXES
  #                   that returns an array of allowed cache prefixes used by
  #                   the class   
  #   
  #   [mandatory]   Define a CLASS method 
  #                 GEN_CACHE_CONTENT(ID_OR_OBJ, CACHE_PREFIX)
  #                   that generates a hash that will be cached
  #                   ID_OR_OBJ is a hash that contains 
  #                     {:id => obj_id, :obj => actual_obj_if_available}
  #                 CACHE_PREFIX is an optional string that can be used to 
  #                   distinguish between different cached info for the same
  #                   object.
  #
  #   [optional]    Define a CLASS method 
  #                 PARSE_CACHE_CONTENT(CONTENT, CACHE_PREFIX)
  #                   that parses the cached content once it is read from 
  #                   redis. Sometimes some JSON.parses are required. If not
  #                   defined, the default method is called (which simply returns
  #                   the cached value as-is)
  #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

  CACHE_KEY_MASTER_PREFIX = 'MultiCache'
  CACHE_KEY_SEPARATOR = ':'
  @@multicache_redis_name = nil

  def self.configure
    raise ArgumentError, "requires a block" unless block_given?
    yield self
  end

  def self.redis_instance(redis_inst_str)
    @@multicache_redis_name = redis_inst_str
  end

  def self.get_redis
    if @redis.blank?
      @redis = eval(@@multicache_redis_name)
    end
    @redis
  end

  included do

    after_save :destroy_obj_cache
    after_destroy :destroy_obj_cache

    def self.get_cached(id_or_obj, cache_category)
      id_and_obj = get_id_and_obj(id_or_obj)

      validate_cache_category(cache_category)

      cache_key = obj_cache_key(id_and_obj[:id])
      cached_json = MultiCache.get_redis.hget(cache_key, cache_category)

      if cached_json.nil?
        # Not found in cache
        cached_hash = gen_cache_content(id_or_obj, cache_category)
        self.write_to_cache(cached_hash, cache_key, cache_category)
      else
        cached_hash = JSON.parse(cached_json)
      end

      parse_cache_content(cached_hash, cache_category)
    end

    def self.write_to_cache(cached_hash, cache_key, cache_category)
      raise "the output of GEN_CACHE_CONTENT must be a hash" if !(cached_hash.is_a? Hash)
      if !cached_hash.nil?
        MultiCache.get_redis.hset(cache_key, cache_category, cached_hash.to_json)
      end
    end

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    # Cache key determination
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    def obj_cache_key(id = self.id)
      self.class.obj_cache_key(id)
    end

    def self.obj_cache_key(id)
      # Do not change ordering since we match keys using this
      raise ArgumentError.new 'Key can not be blank' if id.blank?
      [fixed_cache_prefix(id)].join(CACHE_KEY_SEPARATOR)
    end

    def self.fixed_cache_prefix(id = nil)
      chain = [CACHE_KEY_MASTER_PREFIX, self.name.to_s]
      chain.push(id.to_s.strip) if id.present?
      chain.join(CACHE_KEY_SEPARATOR)
    end

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    # Cache destruction
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

    def destroy_obj_cache(category = nil)
      self.class.destroy_obj_cache(self.id, category)
    end

    def self.destroy_obj_cache(id, category = nil)
      # Delete cache for one object only
      prefix = self.fixed_cache_prefix(id)
      MultiCache.del_from_redis(prefix, category)
    end

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    # Misc
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    def self.parse_cache_content(content, cache_prefix)
      # Default method. Override in including class.
      content
    end

    def self.get_id_and_obj(id_or_obj)
      id_and_obj = {}
      if id_or_obj.class == self
        id_and_obj[:obj] = id_or_obj
        id_and_obj[:id] = obj.id.to_s
      else
        id_and_obj[:id] = id_or_obj.to_s
        # obj = nil # Load it when necessary
      end
      id_and_obj
    end

    def self.validate_cache_category(cache_category)
      if !(multi_cache_prefixes.include? cache_category)
        raise "#{self} Class: cache category '#{cache_category}' " +
                  "must be among #{multi_cache_prefixes}"
      end
    end
  end

  def self.del_from_redis(prefix, category)
    if category.nil?
      MultiCache.get_redis.del(prefix)
    else
      MultiCache.get_redis.hdel(prefix, Array.wrap(category).compact)
    end
  end
end
