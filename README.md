<p align="center">
  <img src="assets/icon.png" alt="Agent Battery icon" width="96" />
  <br />
  <span style="font-size: 32px;"><strong>Agent Battery</strong></span>
  <br />
  <a href="https://github.com/geebos/agent-battery/releases/latest">
    <img src="https://img.shields.io/github/v/release/geebos/agent-battery?label=release" alt="Latest release" />
  </a>
  <br />
</p>

English | [中文](README.zh.md)

A lightweight macOS menu bar app that displays the remaining usage quota of **Claude Code** and **Codex** as a battery-style percentage, so you can always know how much is left in your 5-hour and weekly windows.

<p align="center">
  <img src="assets/setting-en.png" alt="Settings preview" width="70%" />
</p>

## Features

- Persistent menu bar display of your primary tool's remaining 5h quota, with color alerts below thresholds
- Click to open a popover and compare Claude Code / Codex 5h + weekly remaining quota and reset times
- Dual data sources for Claude Code and Codex, with automatic refresh (default 30s, configurable to 1/3/5 minutes)
- One-click Claude Code setup: injects a statusLine hook to collect usage while preserving existing statusLine commands
- Configurable launch at login, refresh interval, warning thresholds, and display mode in settings
- Bilingual localization (Chinese and English)

## Installation

### Option 1: Download release build

Download the latest `.dmg` from [Releases](../../releases) and drag it into `Applications`.

> Since the app is not signed/notarized yet, Gatekeeper may block first launch. Go to *System Settings -> Privacy & Security* and click "Open Anyway".

### Option 2: Build from source

Requires macOS 15+ and Xcode 26.

```bash
git clone https://github.com/<your-name>/agent-battery.git
cd agent-battery
./script/build_and_run.sh        # Build and launch
./script/build_and_run.sh logs   # Launch and follow logs
```

Or open `agent-battery.xcodeproj` in Xcode and run the `agent-battery` scheme.

## First Run: Setup Claude Code

The app **does not proactively connect to any account or API**. It reads usage only from local files:

- **Claude Code**: depends on Claude Code CLI `statusLine` hook writing `rate_limits` into local JSON
- **Codex**: directly reads rate-limit events from `~/.codex/sessions/**/*.jsonl`, no setup needed

So Claude Code requires one-time setup:

1. Launch agent-battery, click menu bar icon -> **Settings**
2. In "Claude Code Settings", click **Setup**
3. The app automatically does the following (details in "How Data Is Read"):
  - Writes two scripts into `~/.agent-battery/` (collector + wrapper)
  - Backs up and updates `~/.claude/settings.json` to point `statusLine.command` to wrapper
  - Preserves and continues executing your existing custom statusLine command, if any
4. Run `claude` once in any directory; after statusLine triggers, you will see Claude Code 5h/weekly remaining in the popover

Codex users **do not need setup**. If `~/.codex/sessions/` rollout files exist locally, the app can read them directly.

## How Data Is Read

The app intentionally avoids network requests and login state. **All usage data comes from local files**.

### Claude Code

When Claude Code CLI refreshes the status line, it sends session metadata (including `rate_limits.five_hour` / `seven_day` with `used_percentage` and `resets_at`) to the script configured by `statusLine.command` via stdin.

During setup, agent-battery replaces `statusLine.command` with its generated **wrapper script** (`~/.agent-battery/claude-status-line-wrapper.sh`), which does two things:

1. Pipes stdin JSON into the **collector script** (`claude-rate-limit-writer.sh`), which extracts `rate_limits` with Python and atomically writes to `~/.agent-battery/claude-usage.json`
2. If the user already has a statusLine command, forwards the same stdin to the original command and preserves its output behavior

`ClaudeCodeUsageProvider` only reads this JSON, converts `remaining = 100 - used_percentage`, and marks stale state. UI does not need to care about collection details.

Related code:

- Injection and uninstall: `agent-battery/Services/ClaudeCodeSetupService.swift`
- Parsing: `agent-battery/Services/ClaudeCodeUsageProvider.swift`

### Codex

Codex CLI writes event streams into `~/.codex/sessions/<date>/*.jsonl`, including `event_msg.token_count.rate_limits` events. The shape is similar to Claude Code (5h/weekly usage and reset time).

`CodexUsageProvider` strategy:

1. Traverse rollout files by modification time descending (max 80 files)
2. For each file, read **last 1MB in reverse** (`tailChunkBytes`) and find the latest rate-limit event
3. Stop early when later files are older than the already-found event timestamp
4. Parse remaining percentage + reset time into `UsageSnapshot`

This avoids loading huge rollout files in full and requires no Codex configuration.

Related code: `agent-battery/Services/CodexUsageProvider.swift`

### State machine

Both providers output unified `UsageSnapshot`. In `UsageStore`, app UI is driven by four states: `available / unavailable / stale / error`. Menu bar text/colors, popover hints, and settings visibility all follow this state model.

## Project structure

```text
agent-battery/
├── agent_batteryApp.swift        # MenuBarExtra entry
├── Models/                       # Data models, including UsageSnapshot
├── Services/                     # Claude/Codex providers + Claude setup
├── Stores/                       # AppSettings, UsageStore (@Observable)
├── Views/                        # Menu bar, popover, settings
├── Support/                      # Formatters, cache, math utilities
└── Shared/Localization/          # xcstrings
docs/                             # PRD and design docs
l10n/                             # YAML source -> xcstrings (merge with make l10n)
script/build_and_run.sh           # Local build/run/debug helper
```

## Development

```bash
./script/build_and_run.sh logs        # follow stdout logs
./script/build_and_run.sh telemetry   # view subsystem logs only
make l10n                             # merge l10n/*.yaml into Localizable.xcstrings
```

For more design background, see `docs/`:

- `[00.01.mvp-prd.md](docs/en/00.01.mvp-prd.md)` - MVP product requirements
- `[00.02.usage-collection.md](docs/en/00.02.usage-collection.md)` - Data collection design
- `[00.03-menu-bar-icon-display.md](docs/en/00.03-menu-bar-icon-display.md)` - Menu bar icon display design

## License

MIT