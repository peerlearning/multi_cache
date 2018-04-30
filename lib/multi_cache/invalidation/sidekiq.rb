require "multi_cache/invalidation"
require "multi_cache/invalidation/blocking"
class MultiCache::Invalidation::Sidekiq
  include ::Sidekiq::Worker
  include MultiCache::Invalidation::Blocking

  CACHE_INV_STACK_EXPIRY = 1.month

  def self.push!(full_pattern)
    # memory = 1
    status_key = gen_status_key(full_pattern)
    redis = MultiCache.get_redis
    if redis.set(status_key, "unprocessed", nx: true, ex: CACHE_INV_STACK_EXPIRY)
      self.perform_async(full_pattern)
      return true
    end

    return false
  end

  def perform(full_pattern, block_size = 100)
    multicache_invalidate_sync(self.class.gen_status_key(full_pattern), true)
    multicache_invalidate_sync(full_pattern, false, 1000)
  end

  def self.gen_status_key(full_pattern)
    tokens = [MultiCache::CACHE_KEY_MASTER_PREFIX, "invalidation", full_pattern.strip.to_s]
    tokens.join(MultiCache::CACHE_KEY_SEPARATOR)
  end
end