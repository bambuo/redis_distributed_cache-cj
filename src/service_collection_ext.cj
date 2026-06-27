package bambuo_spire_redis_cache

import soulsoft_extensions_caching.*
import soulsoft_extensions_injection.*
import soulsoft_extensions_options.*

/// ServiceCollection 扩展方法
///
/// 提供 [RedisDistributedCache] 的依赖注入注册入口，将 [IDistributedCache] 实现
/// 注册为全局单例。所有 Redis 连接细节封装在扩展方法内部。

extend ServiceCollection {
    /// 注册 Redis 分布式缓存服务（使用默认配置）
    ///
    /// 等价于 addRedisDistributedCache { _ => }，使用 [RedisDistributedCacheOptions] 的默认值。
    /// Redis 连接默认指向 127.0.0.1:6379。
    public func addRedisDistributedCache(): ServiceCollection {
        return addRedisDistributedCache { _ => }
    }

    /// 注册 Redis 分布式缓存服务（单例生命周期）
    ///
    /// 将 [RedisDistributedCache] 作为 [IDistributedCache] 的实现注册到 DI 容器中，
    /// 采用全局单例模式。所有 Redis 连接和配置细节封装在内部，
    /// 开发者只需提供连接参数即可。
    ///
    /// @param configureOptions 配置 Redis 连接参数的回调
    /// @return 当前 ServiceCollection 实例（支持链式调用）
    ///
    /// # 示例
    /// ```cangjie
    /// let services = ServiceCollection()
    /// services.addRedisDistributedCache { options =>
    ///     options.host = "127.0.0.1"
    ///     options.port = 6379u16
    /// }
    /// let provider = services.build()
    /// let cache = provider.getOrThrow<IDistributedCache>()
    /// ```
    public func addRedisDistributedCache(configureOptions: (RedisDistributedCacheOptions) -> Unit): ServiceCollection {
        configure<RedisDistributedCacheOptions>(configureOptions)
        addSingleton<IDistributedCache, RedisDistributedCache>()
        return this
    }
}
