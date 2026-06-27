# AGENTS.md

本文为 AI 在此代码库中工作时提供指导。

> **约束来源**：AI 在执行任务时必须同时阅读并遵守 [CLAUDE.md](CLAUDE.md) 中的所有行为准则，两份指令文件共同生效。

## 构建与测试命令

```bash
# 激活仓颉环境（根据实际路径调整）
source /path/to/cangjie/envsetup.sh

# 构建（输出为静态库）
export CANGJIE_STDX_PATH=/path/to/cangjie/stdx/static/stdx
cjpm build

# 运行全部测试（需要本地 Redis 服务器 127.0.0.1:6379）
cjpm test

# 打包（跳过测试和 lint）
cjpm bundle --skip-test --skip-lint

# 发布到中央仓库
cjpm publish

# 通过 cjpm.lock 锁定版本更新依赖
cjpm update
```

## 项目概览

Spire 框架的 Redis 分布式缓存扩展库，基于 [redis-cj](https://github.com/bambuo/redis-cj) 客户端实现 `IDistributedCache` 接口。输出类型为**静态库**（`output-type = "static"`），供其他仓颉项目作为依赖引用。

### 核心架构

```
src/
├── main.cj                      # 包入口 + 使用示例（package bambuo_spire_redis_cache）
├── redis_cache.cj               # RedisDistributedCache 核心实现
├── expiry_utils.cj              # 过期策略纯函数工具
├── service_collection_ext.cj    # DI 注册扩展方法
└── redis_cache_test.cj          # 36 个测试（20 单元 + 16 集成）
```

**包层次**：单一包 `bambuo_spire_redis_cache`（无子包嵌套）

### 核心模块

- **[RedisDistributedCache](src/redis_cache.cj)** — 实现 `IDistributedCache` 接口，持有 `RedisClient` 实例。提供 `get/set/getString/setString/refresh/remove` 方法，支持无过期、相对过期、绝对过期、滑动过期四种策略。滑动过期使用独立元数据键 `{key}:__ttl__` 存储窗口值，在 `get/getString/refresh` 时自动续期。

- **[expiry_utils](src/expiry_utils.cj)** — 纯函数模块，不含任何状态。核心函数 `resolveExpiry` 将 `DistributedCacheEntryOptions` 解析为 Redis `SET` 命令的 `ex/px/exAt/pxAt` 参数元组。

- **[service_collection_ext](src/service_collection_ext.cj)** — `ServiceCollection` 扩展方法，提供 `addRedisDistributedCache` 入口将 `RedisDistributedCache` 注册为 `IDistributedCache` 全局单例。

- **[redis_cache_test](src/redis_cache_test.cj)** — 单元测试只测 `expiry_utils` 中的纯函数（无需 Redis）；集成测试需连接真实 Redis 实例，每个测试用例使用 `uniqueKey` 生成独立键名避免互相干扰。

### 过期策略映射

| IDistributedCache 策略 | Redis 命令 |
|---|---|
| `absoluteExpirationRelativeToNow` | `SET ... EX <seconds>` / `SET ... PX <millis>` |
| `absoluteExpiration` | `SET ... EXAT <timestamp>` |
| `slidingExpiration` | `SET ... EX <seconds>` + 元数据键 `{key}:__ttl__` |

### 依赖项

| 依赖 | 用途 |
|---|---|
| `redis` | Redis 客户端 |
| `soulsoft_extensions_caching` | 提供 `IDistributedCache` 接口与 `DistributedCacheEntryOptions` |
| `soulsoft_extensions_options` | 选项模式 |
| `soulsoft_extensions_injection` | 依赖注入 |

### 导入路径约定

根包路径即为 `bambuo_spire_redis_cache`，外部引用写法：

```cangjie
import bambuo_spire_redis_cache.*
```

### 重要说明

- **环境变量**：构建前必须设置 `CANGJIE_STDX_PATH` 指向 stdx 的对应 output-type 子目录（如 `stdx/static/stdx`）
- **Redis 地址**：集成测试默认连接 `127.0.0.1:6379`（测试源码中的地址可能因开发环境调整而不同，使用时应改为 `127.0.0.1`）
- **键名隔离**：集成测试使用递增计数器 `uniqueKey` 生成独立键名，确保测试可重复运行
- **跨平台编译**：`cjpm.toml` 已配置 macOS/Linux/Windows 四平台的编译选项和链接参数
- **版本号格式**：`1.0.YYYYMMDD`（发布脚本 `scripts/publish.sh` 自动生成）
