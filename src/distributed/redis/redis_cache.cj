package cache.distributed.redis

import redis.client.*
import soulsoft_extensions_caching.*
import std.collection.*
import std.time.*

/// Redis 分布式缓存实现
///
/// 基于 [redis-cj](https://github.com/bambuo/redis-cj) 客户端实现 [IDistributedCache] 接口，
/// 使用 Redis 的 SET/GET/DEL/EXISTS 等命令提供缓存读写能力。
///
/// # 过期策略映射
///
/// | IDistributedCache 策略 | Redis 实现方式 |
/// | --- | --- |
/// | `absoluteExpirationRelativeToNow` | `SET ... EX <seconds>` / `PX <millis>` |
/// | `absoluteExpiration` | `SET ... EXAT <timestamp>` |
/// | `slidingExpiration` | `SET ... EX <seconds>` + 元数据键 `{key}:__ttl__` |
///
/// 滑动过期在 refresh/get 时自动通过 Redis 的 EXPIRE 命令续期；元数据键 `{key}:__ttl__`
/// 存储滑动窗口值（秒），与缓存值同寿命。
///
/// # 线程安全
///
/// RedisClient 本身使用 Mutex + synchronized 保护，因此 RedisDistributedCache 所有方法
/// 也具备线程安全。
///
/// # 示例
/// ```cangjie
/// let cache = RedisDistributedCache("127.0.0.1", 6379u16)
/// cache.setString("key", "value")
/// println(cache.getString("key") ?? "None")
/// cache.remove("key")
/// ```
public class RedisDistributedCache <: IDistributedCache {
    private let client: RedisClient

    // ====================================================================
    // 构造
    // ====================================================================

    /// 使用已有的 RedisClient 实例创建缓存
    ///
    /// @param client 已连接的 RedisClient 实例
    public init(client: RedisClient) {
        this.client = client
    }

    /// 通过主机和端口创建缓存（自动建立连接）
    ///
    /// @param host Redis 服务器主机
    /// @param port Redis 服务器端口
    public init(host: String, port: UInt16) {
        this.client = RedisClient(host, port)
    }

    // ====================================================================
    // IDistributedCache 核心方法
    // ====================================================================

    /// 读取字节数组。键不存在或已过期返回 None。
    public func get(key: String): Option<Array<Byte>> {
        match (client.get(key)) {
            case Some(blob) => Some(blob.toBytes())
            case None => None
        }
    }

    /// 写入字节数组（无过期策略）
    public func set(key: String, value: Array<Byte>): Unit {
        client.set(key, Blob.fromBytes(value))
    }

    /// 写入字节数组（带过期策略）
    public func set(key: String, value: Array<Byte>, options: DistributedCacheEntryOptions): Unit {
        let (ex, px, exAt, pxAt) = resolveExpiry(options)
        client.set(key, Blob.fromBytes(value), ex: ex, px: px, exAt: exAt, pxAt: pxAt)
        storeSlidingMeta(key, options)
    }

    /// 读取字符串。键不存在或已过期返回 None。
    public func getString(key: String): Option<String> {
        match (client.get(key)) {
            case Some(blob) =>
                try {
                    Some(blob.toUtf8())
                } catch (_: Exception) {
                    None
                }
            case None => None
        }
    }

    /// 写入字符串（无过期策略）
    public func setString(key: String, value: String): Unit {
        client.set(key, Blob.fromUtf8(value))
    }

    /// 写入字符串（带过期策略）
    public func setString(key: String, value: String, options: DistributedCacheEntryOptions): Unit {
        let (ex, px, exAt, pxAt) = resolveExpiry(options)
        client.set(key, Blob.fromUtf8(value), ex: ex, px: px, exAt: exAt, pxAt: pxAt)
        storeSlidingMeta(key, options)
    }

    /// 刷新（重置滑动过期窗口）
    ///
    /// 如果键使用了滑动过期策略且在有效期内，重置其 TTL。
    /// 如果键已过期或无滑动过期元数据，仅做存在性检查。
    public func refresh(key: String): Unit {
        if (client.exists([key]) > 0) {
            let ttlKey = slidingTtlKey(key)
            match (client.get(ttlKey)) {
                case Some(meta) =>
                    let ttlStr = meta.toUtf8()
                    if (ttlStr.size > 0) {
                        let ttl = Int64.parse(ttlStr)
                        client.expire(key, ttl)
                        client.expire(ttlKey, ttl)
                    }
                case None => ()
            }
        }
    }

    /// 删除缓存项（同时清理关联的滑动过期元数据）
    public func remove(key: String): Unit {
        client.del([key, slidingTtlKey(key)])
    }

    // ====================================================================
    // 私有辅助
    // ====================================================================

    /// 存储滑动过期元数据
    private func storeSlidingMeta(key: String, options: DistributedCacheEntryOptions): Unit {
        if (let Some(sliding) <- options.slidingExpiration) {
            let ttlKey = slidingTtlKey(key)
            let ttlSec = durationToSecs(sliding)
            client.set(ttlKey, Blob.fromUtf8("${ttlSec}"))
            client.expire(ttlKey, ttlSec)
        }
    }
}
