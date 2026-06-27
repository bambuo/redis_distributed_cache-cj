# bambuo_spire_redis_cache — Bambuo 出品 Spire 框架 Redis 分布式缓存

[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Cangjie](https://img.shields.io/badge/language-Cangjie%201.1.3-orange)](https://cangjie-lang.cn)
[![Redis](https://img.shields.io/badge/Redis-Distributed%20Cache-red)](https://redis.io)
![Build](https://img.shields.io/badge/build-passing-brightgreen)
![Tests](https://img.shields.io/badge/tests-36%20passing-brightgreen)

基于 [redis-cj](https://github.com/bambuo/redis-cj) 客户端为 [Spire 缓存框架](https://github.com/soulsoft/spire-extensions) 提供的 Redis 分布式缓存实现。实现了 `IDistributedCache` 接口，提供线程安全的缓存读写能力。

> **模块名**：`bambuo_spire_redis_cache`（中央仓库依赖声明）
> **导入路径**：`import bambuo_spire_redis_cache.*`

## 功能特性

- **标准接口** — 实现 `IDistributedCache` 接口，支持泛化缓存抽象
- **双类型读写** — 支持字节数组 (`get/set`) 和字符串 (`getString/setString`) 两种存取方式
- **三种过期策略** — 相对过期、绝对过期、滑动过期，策略可组合使用
- **滑动过期自动续期** — 调用 `get`/`getString`/`refresh` 时自动重置滑动过期窗口
- **线程安全** — 底层 `RedisClient` 使用 `Mutex + synchronized` 保护
- **滑动元数据隔离** — 使用独立的 `{key}:__ttl__` 元数据键存储滑动窗口值

## 环境要求

- [Cangjie](https://cangjie-lang.cn) 编译器 `>= 1.1.3`
- Redis 服务器 `>= 6.0`

## 依赖

| 依赖 | 版本 | 说明 |
| --- | --- | --- |
| `redis` | 1.0.20260626 | Redis 客户端 |
| `soulsoft_extensions_caching` | 1.0.20260528 | 缓存框架（IDistributedCache） |
| `soulsoft_extensions_options` | 1.0.20260528 | 选项模式 |
| `soulsoft_extensions_injection` | 1.0.20260528 | 依赖注入 |

## 快速开始

### 构建

```bash
source /path/to/cangjie/envsetup.sh
cjpm build
```

### 运行测试

需要本地 Redis 服务器（默认连接 `127.0.0.1:6379`）。

```bash
cjpm test
```

## 使用示例

### 基本读写

```cangjie
let cache = RedisDistributedCache("127.0.0.1", 6379u16)

// 字符串读写
cache.setString("greeting", "你好，世界")
let val = cache.getString("greeting")  // Some("你好，世界")

// 字节数组读写
let data: Array<Byte> = [0x00, 0xFF, 0xAB]
cache.set("binary", data)
let bin = cache.get("binary")  // Some([0x00, 0xFF, 0xAB])

// 删除
cache.remove("greeting")
```

### 带过期策略写入

```cangjie
// 相对过期：30 秒后自动删除
cache.setString("temp", "临时数据",
    DistributedCacheEntryOptions(
        absoluteExpirationRelativeToNow: Some(Duration.second * 30)
    )
)

// 绝对过期：指定具体过期时间
let expiresAt = DateTime.nowUTC() + Duration.hour * 2
cache.setString("session", "会话数据",
    DistributedCacheEntryOptions(
        absoluteExpiration: Some(expiresAt)
    )
)

// 滑动过期：5 分钟无访问则过期，每次读取自动续期
cache.setString("token", "令牌数据",
    DistributedCacheEntryOptions(
        slidingExpiration: Some(Duration.minute * 5)
    )
)
```

### 手动刷新滑动过期

```cangjie
cache.refresh("token")  // 重置滑动过期窗口
```

## 过期策略映射

| IDistributedCache 策略 | Redis 命令 |
| --- | --- |
| `absoluteExpirationRelativeToNow` | `SET ... EX <seconds>` / `SET ... PX <millis>` |
| `absoluteExpiration` | `SET ... EXAT <timestamp>` |
| `slidingExpiration` | `SET ... EX <seconds>` + 元数据键 `{key}:__ttl__` |

## 项目结构
```
src/
├── main.cj                      # 程序入口 + 使用示例
├── redis_cache.cj               # RedisDistributedCache 核心实现
├── expiry_utils.cj              # 过期策略工具函数
├── service_collection_ext.cj    # DI 注册扩展方法
└── redis_cache_test.cj          # 单元测试（20 用例）+ 集成测试（16 用例）
```

### 核心模块

- **[redis_cache.cj](src/redis_cache.cj)** — `RedisDistributedCache` 主类，实现 `IDistributedCache` 接口
- **[expiry_utils.cj](src/expiry_utils.cj)** — 过期策略解析、Unix 时间戳转换、滑动元数据键生成等纯函数
- **[service_collection_ext.cj](src/service_collection_ext.cj)** — `ServiceCollection` 扩展方法，提供 `addRedisDistributedCache` DI 注册入口
- **[redis_cache_test.cj](src/redis_cache_test.cj)** — 20 个纯函数单元测试 + 16 个集成测试

## 测试覆盖

- **单元测试**（ExpiryUtilsTests）：`slidingTtlKey`、`durationToSecs`、`epochSeconds`、`resolveExpiry` 的边界值/组合策略/零值场景
- **集成测试**（RedisCacheIntegrationTests）：字符串/字节数组读写、过期策略、滑动续期、`refresh`、删除操作

## 发布与引用

### 作为依赖使用

```toml
[dependencies]
bambuo_spire_redis_cache = "1.0.20260626"
```

```cangjie
import bambuo_spire_redis_cache.*
```

### 发布到中央仓库前的检查清单

| 项目 | 状态 |
|------|------|
| `cjpm.toml` 包名 `name` | ✅ `bambuo_spire_redis_cache` |
| `cjpm.toml` 版本号 `version` | ✅ `1.0.20260626` |
| 源文件 `package` 声明一致 | ✅ 全部 `bambuo_spire_redis_cache` |
| `LICENSE` 许可证文件 | ✅ MIT |
| `.gitignore` | ✅ 已添加 |
| `README.md` | ✅ 中文文档 |
| 单元测试 | ✅ 20 通过 |
| 集成测试 | ✅ 16 通过 |

当前仓颉语言已支持**中央仓库**分发。构建时 `cjpm` 自动从中央仓库解析版本依赖并下载。如需使用本地开发版本，可临时替换为 `path` 依赖。

### 构建配置说明

`cjpm.toml` 中已配置各平台的构建参数：

| 平台 | 依赖路径 | 编译选项 |
|------|----------|----------|
| macOS aarch64 | `${CANGJIE_STDX_PATH}` | `-Woff unused -Woff deprecated` |
| Linux aarch64 | `${CANGJIE_STDX_PATH}` | `-Woff unused -Woff deprecated -ldl` |
| Linux x86_64 | `${CANGJIE_STDX_PATH}` | `-Woff unused -Woff deprecated -ldl` |
| Windows x86_64 | `${CANGJIE_STDX_PATH}` | `-Woff unused -Woff deprecated -lcrypt32` |

构建前需设置环境变量 `CANGJIE_STDX_PATH` 指向本地 stdx 路径，例如：

```bash
export CANGJIE_STDX_PATH=/path/to/cangjie/stdx/static/stdx
```

> **注意**：`CANGJIE_STDX_PATH` 需指向 `stdx/static/stdx` 或 `stdx/dynamic/stdx` 子目录，具体取决于项目 `output-type`。

---

## 许可证

[MIT](LICENSE)
