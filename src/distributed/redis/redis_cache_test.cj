package cache.distributed.redis

import redis.client.*
import soulsoft_extensions_caching.*
import std.time.*

/// ──────────────────────────────────────────────
/// 单元测试：expiry_utils 纯函数
/// ──────────────────────────────────────────────

@Test
class ExpiryUtilsTests {
    // ===== slidingTtlKey =====

    @TestCase
    func slidingTtlKeyAppendsSuffix() {
        @Expect(slidingTtlKey("mykey"), "mykey:__ttl__")
    }

    @TestCase
    func slidingTtlKeyWithPrefix() {
        @Expect(slidingTtlKey("chat:session:alice"), "chat:session:alice:__ttl__")
    }

    @TestCase
    func slidingTtlKeyEmpty() {
        @Expect(slidingTtlKey(""), ":__ttl__")
    }

    // ===== durationToSecs =====

    @TestCase
    func durationToSecsExactSecond() {
        @Expect(durationToSecs(Duration.second * 5), 5)
    }

    @TestCase
    func durationToSecsCeilMs() {
        @Expect(durationToSecs(Duration.millisecond * 1500), 2)  // 1.5秒 → 2秒
    }

    @TestCase
    func durationToSecsLessThanSecond() {
        @Expect(durationToSecs(Duration.millisecond * 500), 1)   // 500ms → 1秒
    }

    @TestCase
    func durationToSecsZero() {
        @Expect(durationToSecs(Duration.millisecond * 0), 1)     // 0 → 最小1秒
    }

    @TestCase
    func durationToSecsOneMinute() {
        @Expect(durationToSecs(Duration.minute), 60)
    }

    // ===== epochSeconds =====

    @TestCase
    func epochSecondsZero() {
        let dt = DateTime.fromEpochSecond(0)
        @Expect(epochSeconds(dt), 0)
    }

    @TestCase
    func epochSecondsKnownTs() {
        // 2024-01-01 00:00:00 UTC = 1704067200
        let dt = DateTime.fromEpochSecond(1704067200)
        @Expect(epochSeconds(dt), 1704067200)
    }

    @TestCase
    func epochSecondsNow() {
        let now = DateTime.nowUTC()
        let ts = epochSeconds(now)
        // 应该接近当前时间，误差不超过5秒
        let nowTs = epochSeconds(DateTime.nowUTC())
        @Expect((ts - nowTs).abs() <= 1, true)
    }

    // ===== resolveExpiry =====

    @TestCase
    func resolveExpiryNone() {
        let opts = DistributedCacheEntryOptions()
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        @Expect(ex, None)
        @Expect(px, None)
        @Expect(exAt, None)
        @Expect(pxAt, None)
    }

    @TestCase
    func resolveExpiryRelativeExactSecond() {
        let opts = DistributedCacheEntryOptions(
            absoluteExpirationRelativeToNow: Some(Duration.second * 30)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        match (ex) {
            case Some(v) => @Expect(v, 30)
            case None => @Fail("ex 应为 Some(30)")
        }
        @Expect(px, None)
        @Expect(exAt, None)
    }

    @TestCase
    func resolveExpiryRelativeWithMs() {
        let opts = DistributedCacheEntryOptions(
            absoluteExpirationRelativeToNow: Some(Duration.millisecond * 1500)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        @Expect(ex, None)
        match (px) {
            case Some(v) => @Expect(v, 1500)
            case None => @Fail("px 应为 Some(1500)")
        }
    }

    @TestCase
    func resolveExpiryAbsolute() {
        let dt = DateTime.fromEpochSecond(2000000000)
        let opts = DistributedCacheEntryOptions(
            absoluteExpiration: Some(dt)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        @Expect(ex, None)
        @Expect(px, None)
        match (exAt) {
            case Some(v) => @Expect(v, 2000000000)
            case None => @Fail("exAt 应为 Some(2000000000)")
        }
    }

    @TestCase
    func resolveExpirySliding() {
        let opts = DistributedCacheEntryOptions(
            slidingExpiration: Some(Duration.minute * 10)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        match (ex) {
            case Some(v) => @Expect(v, 600)
            case None => @Fail("ex 应为 Some(600)")
        }
        @Expect(exAt, None)
    }

    @TestCase
    func resolveExpiryCombinedSlidingAndAbsolute() {
        let dt = DateTime.fromEpochSecond(3000000000)
        let opts = DistributedCacheEntryOptions(
            slidingExpiration: Some(Duration.second * 300),
            absoluteExpirationRelativeToNow: Some(Duration.hour)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        match (ex) {
            case Some(v) => @Expect(v, 300)  // sliding 300s
            case None => @Fail("ex 应来自 sliding")
        }
        @Expect(exAt, None)  // absoluteExpirationRelativeToNow 也进 ex，但被 sliding 覆盖
        // 注意：sliding 和 relative 都是 ex，sliding 优先值进入
    }

    @TestCase
    func resolveExpirySlidingMsTriggerPx() {
        let opts = DistributedCacheEntryOptions(
            slidingExpiration: Some(Duration.millisecond * 500)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        @Expect(ex, None)
        match (px) {
            case Some(v) => @Expect(v, 500)
            case None => @Fail("px 应为 Some(500)")
        }
    }

    @TestCase
    func resolveExpiryAllThree() {
        let dt = DateTime.fromEpochSecond(4000000000)
        let opts = DistributedCacheEntryOptions(
            slidingExpiration: Some(Duration.second * 60),
            absoluteExpiration: Some(dt),
            absoluteExpirationRelativeToNow: Some(Duration.second * 120)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        match (ex) {
            case Some(v) => @Expect(v, 60)
            case None => @Fail("ex 应为 Some(60)")
        }
        match (exAt) {
            case Some(v) => @Expect(v, 4000000000)
            case None => @Fail("exAt 应为 Some(4000000000)")
        }
    }

    @TestCase
    func resolveExpiryZeroDurationIgnored() {
        let opts = DistributedCacheEntryOptions(
            absoluteExpirationRelativeToNow: Some(Duration.millisecond * 0)
        )
        let (ex, px, exAt, pxAt) = resolveExpiry(opts)
        @Expect(ex, None)
        @Expect(px, None)
    }
}

/// ──────────────────────────────────────────────
/// 集成测试：RedisDistributedCache
/// ──────────────────────────────────────────────
/// 需要本地 Redis 服务器 127.0.0.1:6379
/// 每个测试用独立键名前缀避免互相干扰

@Test
class RedisCacheIntegrationTests {
    private var keyCounter: Int64 = 0

    private func createCache(): RedisDistributedCache {
        RedisDistributedCache("127.0.0.1", 6379u16)
    }

    private func uniqueKey(prefix: String): String {
        keyCounter++
        "test:${prefix}_${keyCounter}"
    }

    // ===== 字符串读写 =====

    @TestCase
    func setAndGetString() {
        let cache = createCache()
        let k = uniqueKey("str")
        cache.setString(k, "hello")
        let val = cache.getString(k)
        match (val) {
            case Some(s) => @Expect(s, "hello")
            case None => @Fail("getString 返回 None")
        }
        cache.remove(k)
    }

    @TestCase
    func getStringNonexistent() {
        let cache = createCache()
        let val = cache.getString("nonexistent_${keyCounter++}")
        @Expect(val, None)
    }

    @TestCase
    func setStringAndOverwrite() {
        let cache = createCache()
        let k = uniqueKey("ovr")
        cache.setString(k, "first")
        cache.setString(k, "second")
        let val = cache.getString(k)
        match (val) {
            case Some(s) => @Expect(s, "second")
            case None => @Fail("覆盖后 getString 返回 None")
        }
        cache.remove(k)
    }

    // ===== 字节数组读写 =====

    @TestCase
    func setAndGetBytes() {
        let cache = createCache()
        let k = uniqueKey("bin")
        let bytes: Array<Byte> = [0x00, 0xFF, 0xAB, 0xCD]
        cache.set(k, bytes)
        let val = cache.get(k)
        match (val) {
            case Some(b) =>
                @Expect(b.size, 4)
                @Expect(b[0], 0x00u8)
                @Expect(b[1], 0xFFu8)
                @Expect(b[2], 0xABu8)
                @Expect(b[3], 0xCDu8)
            case None => @Fail("get 返回 None")
        }
        cache.remove(k)
    }

    @TestCase
    func getNonexistentBytes() {
        let cache = createCache()
        let val = cache.get("nonexistent_bin_${keyCounter++}")
        @Expect(val, None)
    }

    // ===== 删除 =====

    @TestCase
    func removeKey() {
        let cache = createCache()
        let k = uniqueKey("rm")
        cache.setString(k, "to-delete")
        @Expect(cache.getString(k) ?? "None" != "None", true)
        cache.remove(k)
        @Expect(cache.getString(k), None)
    }

    @TestCase
    func removeNonexistentKey() {
        let cache = createCache()
        // 删除不存在的键不应抛异常
        cache.remove("nonexistent_rm_${keyCounter++}")
    }

    // ===== 相对过期 =====

    @TestCase
    func setWithRelativeExpiry() {
        let cache = createCache()
        let k = uniqueKey("exp-rel")
        cache.setString(
            k,
            "expires-fast",
            DistributedCacheEntryOptions(
                absoluteExpirationRelativeToNow: Some(Duration.second * 2)
            )
        )
        // 立即存在
        @Expect(cache.getString(k) ?? "None" != "None", true)
        // 等过期
        sleep(Duration.second * 3)
        @Expect(cache.getString(k), None)
    }

    // ===== 滑动过期 =====

    @TestCase
    func setWithSlidingExpiry() {
        let cache = createCache()
        let k = uniqueKey("slid")
        cache.setString(
            k,
            "sliding-test",
            DistributedCacheEntryOptions(
                slidingExpiration: Some(Duration.second * 3)
            )
        )
        // 第一次读取 - 存在
        @Expect(cache.getString(k) ?? "None" != "None", true)
        // 等待接近过期边界再读（续期）
        sleep(Duration.second * 2)
        @Expect(cache.getString(k) ?? "None" != "None", true)
        // 再次等待接近过期边界再读（续期）
        sleep(Duration.second * 2)
        @Expect(cache.getString(k) ?? "None" != "None", true)
        // 等足够久到过期
        sleep(Duration.second * 4)
        @Expect(cache.getString(k), None)
    }

    // ===== refresh =====

    @TestCase
    func refreshExtendsTtl() {
        let cache = createCache()
        let k = uniqueKey("ref")
        cache.setString(
            k,
            "refresh-me",
            DistributedCacheEntryOptions(
                slidingExpiration: Some(Duration.second * 3)
            )
        )
        sleep(Duration.second * 2)
        // refresh 续期
        cache.refresh(k)
        // 如果没续期，再过 2 秒就过期了；续期后还能读到
        sleep(Duration.second * 2)
        @Expect(cache.getString(k) ?? "None" != "None", true)
        cache.remove(k)
    }

    @TestCase
    func refreshNonexistentKey() {
        let cache = createCache()
        // 刷新不存在的键不应抛异常
        cache.refresh("nonexistent_ref_${keyCounter++}")
    }

    // ===== 无过期 =====

    @TestCase
    func setWithoutExpiry() {
        let cache = createCache()
        let k = uniqueKey("noexp")
        cache.setString(k, "persistent")
        @Expect(cache.getString(k) ?? "None" != "None", true)
        cache.remove(k)
    }
}

/// 测试用睡眠辅助
private func sleep(d: Duration): Unit {
    let ms = d.toMilliseconds()
    if (ms > 0) {
        std.time.sleep(Duration(unit: DurationUnit.MILLISECOND, value: ms))
    }
}
