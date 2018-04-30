module MultiCache::RedisHelpers
  extend ActiveSupport::Concern
  included do
    def self.get_redis
      if @redis.blank?
        redis_name = MultiCache.class_variable_get(:@@multicache_redis_name)
        raise "Redis not found!" if redis_name.blank?
        @redis = eval(redis_name)
      end
      @redis
    end
  end  
end