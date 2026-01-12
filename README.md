# Toasty

<img src="icons/toasty.png" alt="Toasty mascot" width="128" align="right">

A tiny cross-platform notification CLI for Windows and macOS that knows how to hook into Coding Agents so you get notified when their long running tasks are finished. ~229 KB on Windows, ~100 KB on macOS, no dependencies.

## Quick Start

### Windows
```cmd
toasty "Hello World" -t "Toasty"
```

### macOS
```bash
toasty "Hello World" -t "Toasty"
```

That's it. On Windows, Toasty auto-registers on first run. On macOS, it requests notification permissions on first use.

## Usage

```
toasty <message> [options]
toasty --install [agent]
toasty --uninstall
toasty --status

Options:
  -t, --title <text>   Set notification title (default: "Notification")
  --app <name>         Use AI CLI preset (claude, copilot, gemini)
  -h, --help           Show this help
  --install [agent]    Install hooks for AI CLI agents (claude, gemini, copilot, or all)
  --uninstall          Remove hooks from all AI CLI agents
  --status             Show installation status
```

## AI CLI Auto-Detection

Toasty automatically detects when it's called from a known AI CLI tool and applies the appropriate icon and title. No flags needed!

**Auto-detected tools:**
- Claude Code
- GitHub Copilot
- Google Gemini CLI

```cmd
# Called from Claude - automatically uses Claude preset
toasty "Analysis complete"

# Called from Copilot - automatically uses Copilot preset
toasty "Code review done"
```

### Manual Preset Selection

Override auto-detection with `--app`:

```cmd
toasty "Processing finished" --app claude
toasty "Build succeeded" --app copilot
toasty "Query done" --app gemini
```

## One-Click Hook Installation

Toasty can automatically configure AI CLI agents to show notifications when tasks complete.

**Note**: On macOS, hook installation creates new configuration files. If you have existing hooks, you'll need to manually merge the toasty hooks with your existing configuration.

### Supported Agents

| Agent | Config Path | Hook Event | Scope |
|-------|-------------|------------|-------|
| Claude Code | `~/.claude/settings.json` | `Stop` | User |
| Gemini CLI | `~/.gemini/settings.json` | `AfterAgent` | User |
| GitHub Copilot | `.github/hooks/toasty.json` | `sessionEnd` | Repo |

### Auto-Install

```cmd
# Install for all detected agents
toasty --install

# Install for specific agent
toasty --install claude
toasty --install gemini
toasty --install copilot

# Check what's installed
toasty --status

# Remove all hooks
toasty --uninstall
```

### Example Output

```
Detecting AI CLI agents...
  [x] Claude Code found
  [x] Gemini CLI found
  [ ] GitHub Copilot (in current repo)

Installing toasty hooks...
  [x] Claude Code: Added Stop hook
  [x] Gemini CLI: Added AfterAgent hook

Done! You'll get notifications when AI agents finish.
```

## Manual Integration

If you prefer to configure hooks manually:

### Claude Code

Add to `~/.claude/settings.json`:

**Windows:**
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "C:\\path\\to\\toasty.exe \"Claude finished\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

**macOS/Linux:**
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/toasty \"Claude finished\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

### Gemini CLI

Add to `~/.gemini/settings.json`:

**Windows:**
```json
{
  "hooks": {
    "AfterAgent": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "C:\\path\\to\\toasty.exe \"Gemini finished\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

**macOS/Linux:**
```json
{
  "hooks": {
    "AfterAgent": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/usr/local/bin/toasty \"Gemini finished\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

### GitHub Copilot

Add to `.github/hooks/toasty.json`:

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      {
        "type": "command",
        "bash": "toasty 'Copilot finished'",
        "powershell": "toasty.exe 'Copilot finished'",
        "timeoutSec": 5
      }
    ]
  }
}
```

## Building

### Windows

Requires Visual Studio 2022 with C++ workload.

```cmd
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

Output: `build\Release\toasty.exe`

### macOS

Requires Xcode command line tools.

```bash
cmake -S . -B build
cmake --build build --config Release
```

Output: `build/toasty`

To install globally:
```bash
sudo cp build/toasty /usr/local/bin/
```

## License

MIT
