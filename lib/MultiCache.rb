require "MultiCache/version"

module MultiCache
  extend ActiveSupport::Concern

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
  # 
  # After installation:
  #
  #   Create config/initializers/init_multi_cache.rb
  #   and add the line
  #       Rails.application.config.multi_cache_redis = "<redis-instance>"
  #     where <redis-instance> is the Redis::Namespace object to be used by 
  #     MultiCache for caching
  #     Please ensure that the redis-instance is specified in quotes
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

  CACHE_KEY_MASTER_PREFIX   = "MultiCache"
  CACHE_KEY_SEPARATOR       = "_"
  MULTICACHE_REDIS          = eval(Rails.application.config.multi_cache_redis)

  included do

    after_save    :destroy_obj_cache
    after_destroy :destroy_obj_cache

    def self.get_cached(id_or_obj, cache_prefix)
      id_and_obj = get_id_and_obj(id_or_obj)

      validate_cache_prefix(cache_prefix)

      cache_key = obj_cache_key(id_and_obj[:id], cache_prefix)
      cached = MULTICACHE_REDIS.hgetall(cache_key)

      if cached.blank?
        cached = gen_cache_content(id_or_obj, cache_prefix)

        raise "the output of GEN_CACHE_CONTENT must be a hash" if !(cached.is_a?Hash)
        if cached.present?
          MULTICACHE_REDIS.hmset(cache_key, *(cached.to_a.reduce([], :+)))
        end
        cached = MULTICACHE_REDIS.hgetall(cache_key)
      end

      parse_cache_content(cached, cache_prefix)
    end

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    # Cache key determination
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    def obj_cache_key(cache_prefix)
      self.class.obj_cache_key(self.id, cache_prefix)
    end

    def self.obj_cache_key(id, custom_prefix)
      # Do not change ordering since we match keys using this
      [fixed_cache_prefix(id), custom_prefix.to_s].join(CACHE_KEY_SEPARATOR)
    end

    def self.fixed_cache_prefix(id = nil)
      chain = [CACHE_KEY_MASTER_PREFIX, self.name.to_s]
      chain.push(id.to_s.strip) if id.present?
      chain.join(CACHE_KEY_SEPARATOR)
    end

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    # Cache destruction
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
    def destroy_obj_cache(cb_obj = nil)
      self.class.destroy_obj_cache(self.id)
    end

    def self.destroy_obj_cache(id)
      # Delete cache for one object only
      prefix = self.fixed_cache_prefix(id)
      MultiCache.del_from_redis(prefix)
    end

    def self.destroy_class_cache
      # Destroy cache for all objects of this class
      prefix = self.fixed_cache_prefix
      MultiCache.del_from_redis(prefix)
    end

    def self.destroy_cache_keys
      # Destroy cache for all MultiCache
      MultiCache.del_from_redis(CACHE_KEY_MASTER_PREFIX)
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

    def self.validate_cache_prefix(cache_prefix)
      if !(multi_cache_prefixes.include?cache_prefix)
        raise "#{self} Class: cache prefix '#{cache_prefix}' " + 
              "must be among #{multi_cache_prefixes}"
      end
    end
  end

  def self.del_from_redis(prefix_match) 
    Thread.new do
      MULTICACHE_REDIS.keys("#{prefix_match}*").each do |prefix|
        MULTICACHE_REDIS.del(prefix)
        # TODO: Use scan instead of keys
      end
    end
  end
end
