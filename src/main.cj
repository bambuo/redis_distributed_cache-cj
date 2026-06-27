package bambuo_spire_redis_cache

import std.time.*
import soulsoft_extensions_caching.*
import soulsoft_extensions_options.*

main() {
    println("╔══════════════════════════════════════════╗")
    println("║    Redis 分布式缓存 — 使用示例            ║")
    println("╚══════════════════════════════════════════╝")
    println()

    // ────────────────────────────────────────────
    // 1. 创建缓存实例
    // ────────────────────────────────────────────
    println("── 1. 创建缓存实例 ──")
    let cache = RedisDistributedCache("127.0.0.1", 6379u16)
    println("✓ 已连接到 Redis 127.0.0.1:6379")
    println()

    // ────────────────────────────────────────────
    // 2. 基本字符串读写
    // ────────────────────────────────────────────
    println("── 2. 基本字符串读写 ──")
    cache.setString("demo:greeting", "你好，分布式缓存！")
    let greeting = cache.getString("demo:greeting")
    println("  写入 → 读取: ${greeting ?? "(None)"}")
    println()

    // ────────────────────────────────────────────
    // 3. 字节数组读写
    // ────────────────────────────────────────────
    println("── 3. 字节数组读写 ──")
    let data: Array<Byte> = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
    cache.set("demo:binary", data)
    match (cache.get("demo:binary")) {
        case Some(b) =>
            println("  写入 5 字节 → 读取: ${b.size} bytes")
        case None =>
            println("  ✗ 读取失败")
    }
    println()

    // ────────────────────────────────────────────
    // 4. 相对过期（30 秒后自动删除）
    // ────────────────────────────────────────────
    println("── 4. 相对过期写入（30s 后过期）──")
    cache.setString("demo:temp", "临时数据",
        DistributedCacheEntryOptions(
            absoluteExpirationRelativeToNow: Some(Duration.second * 30)
        )
    )
    println("  ✓ demo:temp 已写入，将在 30 秒后过期")
    println()

    // ────────────────────────────────────────────
    // 5. 滑动过期（5 分钟无访问则过期）
    // ────────────────────────────────────────────
    println("── 5. 滑动过期写入（5min 窗口）──")
    cache.setString("demo:token", "会话令牌",
        DistributedCacheEntryOptions(
            slidingExpiration: Some(Duration.minute * 5)
        )
    )
    // 读取一次（自动续期）
    let token = cache.getString("demo:token")
    println("  首次读取: ${token ?? "(None)"}（滑动窗口已续期）")
    // 手动刷新
    cache.refresh("demo:token")
    println("  ✓ refresh() 已手动续期")
    println()

    // ────────────────────────────────────────────
    // 6. 绝对过期（指定具体过期时间）
    // ────────────────────────────────────────────
    println("── 6. 绝对过期写入（1 小时后过期）──")
    let expiresAt = DateTime.nowUTC() + Duration.hour
    cache.setString("demo:session", "会话数据",
        DistributedCacheEntryOptions(
            absoluteExpiration: Some(expiresAt)
        )
    )
    println("  ✓ demo:session 将在 ${expiresAt} 过期")
    println()

    // ────────────────────────────────────────────
    // 7. 删除缓存项
    // ────────────────────────────────────────────
    println("── 7. 清理所有演示键 ──")
    for (key in ["demo:greeting", "demo:binary", "demo:temp", "demo:token", "demo:session"]) {
        cache.remove(key)
        println("  ✗ ${key} 已删除")
    }
    println()
    println("全部示例执行完成！")
}