[English](README.md) | 中文

# agent-battery

一个 macOS 状态栏小工具，用「电量百分比」的形式展示 **Claude Code** 与 **Codex** 的 usage 剩余额度，让你随时知道 5 小时窗口和每周额度还剩多少。

platform swift

## 功能

- 状态栏常驻显示主工具的 5h 剩余百分比，低于阈值时变色提醒
- 点击展开弹窗，对比查看 Claude Code / Codex 的 5h 与 weekly 剩余额度、重置时间
- 支持 Claude Code 与 Codex 双数据源，自动定时刷新（默认 30s，可调 1/3/5 分钟）
- 一键 setup Claude Code：自动注入 statusLine hook 抓取 usage，原有 statusLine 命令会保留并继续执行
- 开机启动、刷新频率、提醒/警告阈值、显示模式等可在设置页配置
- 中英双语本地化

## 安装

### 方式一：下载发布版

到 [Releases](../../releases) 下载最新的 `.dmg`，拖入 `Applications` 即可。

> 由于未签名/未公证，首次启动可能被 Gatekeeper 拦截。在 *系统设置 → 隐私与安全性* 中点击「仍要打开」即可。

### 方式二：源码构建

需要 macOS 15+ 与 Xcode 26。

```bash
git clone https://github.com/<your-name>/agent-battery.git
cd agent-battery
./script/build_and_run.sh        # 构建并启动
./script/build_and_run.sh logs   # 启动并跟随日志
```

或直接用 Xcode 打开 `agent-battery.xcodeproj` 运行 `agent-battery` scheme。

## 初次使用：Setup Claude Code

应用本身**不会主动连接任何账号或 API**。它通过解析本地数据文件获取 usage：

- **Claude Code**：依赖 Claude Code CLI 的 `statusLine` hook 把 `rate_limits` 写到本地 JSON
- **Codex**：直接读取 `~/.codex/sessions/**/*.jsonl` 中的 rate-limit 事件，无需配置

因此 Claude Code 第一次使用前需要执行一次 setup：

1. 启动 agent-battery，点击状态栏图标 → **Settings**
2. 在「Claude Code 设置」一节点击 **Setup**
3. 应用会自动完成以下事情（详见下文「读取原理」）：
  - 在 `~/.agent-battery/` 写入两个脚本（采集器 + wrapper）
  - 备份并修改 `~/.claude/settings.json`，把 `statusLine.command` 指向 wrapper
  - 如果你已经有自定义的 statusLine 命令，会被完整保留并继续执行
4. 在任意目录运行一次 `claude`，触发 statusLine 后，弹窗即可看到 Claude Code 的 5h / weekly 剩余额度

Codex 用户**无需 setup**，只要本地有 `~/.codex/sessions/` 的 rollout 文件，应用就能直接读取。

## 读取原理

应用刻意避开网络请求与登录态，**所有 usage 数据都来自本地文件**。

### Claude Code

Claude Code CLI 每次刷新状态栏时，会把当前会话的元数据（含 `rate_limits.five_hour` / `seven_day` 的 `used_percentage` 与 `resets_at`）通过 stdin 传给 `statusLine.command` 配置的脚本。

agent-battery 的 setup 流程会把 `statusLine.command` 替换成自己生成的 **wrapper 脚本**（`~/.agent-battery/claude-status-line-wrapper.sh`），它做两件事：

1. 把 stdin 的 JSON 喂给 **collector 脚本**（`claude-rate-limit-writer.sh`），后者用 Python 把 `rate_limits` 抽出来，原子写入 `~/.agent-battery/claude-usage.json`
2. 如果用户原本就有 statusLine 命令，把同一份 stdin 转发给原命令并输出，状态栏行为保持不变

应用的 `ClaudeCodeUsageProvider` 只负责读取这个 JSON、转换为 `remaining = 100 - used_percentage`、判断 stale，UI 完全不感知抓取细节。

相关代码：

- 注入与卸载：`agent-battery/Services/ClaudeCodeSetupService.swift`
- 解析：`agent-battery/Services/ClaudeCodeUsageProvider.swift`

### Codex

Codex CLI 会把每次会话的事件流写到 `~/.codex/sessions/<日期>/*.jsonl`，其中包含 `event_msg.token_count.rate_limits` 事件，结构与 Claude Code 类似（5h / weekly 的使用率与重置时间）。

`CodexUsageProvider` 的策略：

1. 按修改时间倒序遍历 rollout 文件（最多 80 个）
2. 对每个文件 **从尾部反向读取 1MB**（`tailChunkBytes`），找出最近一次 rate-limit 事件
3. 一旦后续文件的修改时间早于已找到的事件时间就提前停止扫描
4. 解析出剩余百分比和 reset 时间后输出 `UsageSnapshot`

这样即便 rollout 文件很大也不会全量加载，且无需 Codex 做任何配置。

相关代码：`agent-battery/Services/CodexUsageProvider.swift`

### 状态机

两个 Provider 输出统一的 `UsageSnapshot`，应用在 `UsageStore` 中按 `available / unavailable / stale / error` 四种状态驱动 UI。状态栏百分比与配色、弹窗提示、设置页可见性都由这套状态决定。

## 项目结构

```
agent-battery/
├── agent_batteryApp.swift        # MenuBarExtra 入口
├── Models/                       # UsageSnapshot 等数据模型
├── Services/                     # Claude / Codex 数据源 + Claude setup
├── Stores/                       # AppSettings、UsageStore（@Observable）
├── Views/                        # 状态栏、弹窗、设置页
├── Support/                      # 格式化、缓存、数学工具
└── Shared/Localization/          # xcstrings
docs/                             # PRD 与设计文档
l10n/                             # YAML 源 → xcstrings（make l10n 合并）
script/build_and_run.sh           # 本地构建/运行/调试
```

## 开发

```bash
./script/build_and_run.sh logs        # 跟随 stdout 日志
./script/build_and_run.sh telemetry   # 仅查看 subsystem 日志
make l10n                             # 把 l10n/*.yaml 合并到 Localizable.xcstrings
```

更多设计背景详见 `docs/`：

- `[00.01.mvp-prd.md](docs/00.01.mvp-prd.md)` — MVP 产品需求
- `[00.02.usage-collection.md](docs/00.02.usage-collection.md)` — 数据采集方案
- `[00.03-menu-bar-icon-display.md](docs/00.03-menu-bar-icon-display.md)` — 状态栏图标显示

## License

MIT