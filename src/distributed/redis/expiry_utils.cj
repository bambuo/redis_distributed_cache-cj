package cache.distributed.redis

import soulsoft_extensions_caching.*
import std.time.*

/// 从 DistributedCacheEntryOptions 解析 Redis SET 参数
///
/// 返回 (ex, px, exAt, pxAt) 元组，分别对应：
/// - ex: 过期秒数（SET ... EX）
/// - px: 过期毫秒数（SET ... PX）
/// - exAt: 过期 Unix 时间戳秒（SET ... EXAT）
/// - pxAt: 过期 Unix 时间戳毫秒（SET ... PXAT）
internal func resolveExpiry(options: DistributedCacheEntryOptions): (Option<Int64>, Option<Int64>, Option<Int64>, Option<Int64>) {
    var ex: Option<Int64> = None
    var px: Option<Int64> = None
    var exAt: Option<Int64> = None
    var pxAt: Option<Int64> = None

    if (let Some(rel) <- options.absoluteExpirationRelativeToNow) {
        let ms = rel.toMilliseconds()
        if (ms > 0) {
            if (ms >= 1000 && ms % 1000 == 0) {
                ex = Some(ms / 1000)
            } else {
                px = Some(ms)
            }
        }
    }

    if (let Some(abs) <- options.absoluteExpiration) {
        let totalMs = epochMilliseconds(abs)
        if (totalMs % 1000 == 0) {
            exAt = Some(totalMs / 1000)
        } else {
            pxAt = Some(totalMs)
        }
    }

    if (let Some(sliding) <- options.slidingExpiration) {
        let ms = sliding.toMilliseconds()
        if (ms > 0) {
            if (ms >= 1000 && ms % 1000 == 0) {
                ex = Some(ms / 1000)
            } else {
                px = Some(ms)
            }
        }
    }

    (ex, px, exAt, pxAt)
}

/// Duration 转秒数（向上取整）
internal func durationToSecs(d: Duration): Int64 {
    let ms = d.toMilliseconds()
    if (ms <= 0) { 1 }
    else { (ms + 999) / 1000 }
}

/// 将 DateTime 转为 Unix 毫秒级时间戳
internal func epochMilliseconds(dt: DateTime): Int64 {
    let diff = dt - DateTime.UnixEpoch
    diff.toMilliseconds()
}

/// 将 DateTime 转为 Unix 秒级时间戳
internal func epochSeconds(dt: DateTime): Int64 {
    let totalMs = epochMilliseconds(dt)
    totalMs / 1000
}

/// 生成滑动过期 TTL 元数据的键名
internal func slidingTtlKey(key: String): String {
    "${key}:__ttl__"
}
