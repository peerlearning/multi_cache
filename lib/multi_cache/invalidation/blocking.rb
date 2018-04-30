require "multi_cache/invalidation"
module MultiCache::Invalidation::Blocking
  extend ActiveSupport::Concern
  included do
    def multicache_invalidate_sync(full_pattern, exact_match = false, block_size = 100)

      redis = MultiCache.get_redis
      full_pattern = full_pattern.to_s
      return nil if full_pattern.blank?
      return nil if full_pattern == "*" # let's not delete everything

      if exact_match
        multi_cache_del_redis_key(redis, full_pattern)
      else
        redis.scan_each(match: full_pattern.to_s, count: block_size).each do |prefixes|
          multi_cache_del_redis_key(redis, prefixes)
        end
      end
    end

    def multi_cache_del_redis_key(redis, key)
      redis.del(key)
    end  
  end
end