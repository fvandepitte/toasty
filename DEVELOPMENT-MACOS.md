# macOS Development Guide

## Overview

The macOS version of Toasty uses the native UserNotifications framework to display notifications. Unlike the Windows version which uses C++/WinRT, the macOS version is written in Objective-C++ (.mm file).

## Architecture

### Key Components

- **UserNotifications Framework**: macOS 10.14+ native notification system
- **AppKit**: For application activation and focus management
- **Foundation**: Core Objective-C functionality

### Differences from Windows Version

| Feature | Windows | macOS |
|---------|---------|-------|
| Notification API | Windows.UI.Notifications (WinRT) | UserNotifications framework |
| Registration | Start Menu shortcut with AUMID | Automatic on first use |
| Click-to-focus | Protocol handler (toasty://) | Application activation |
| Icon support | Embedded resources + temp files | File path to PNG |
| File size | ~229 KB | ~100 KB |

## Building

### Prerequisites

- macOS 10.14 or later
- Xcode Command Line Tools
- CMake 3.20+

### Build Commands

```bash
# Configure
cmake -S . -B build

# Build Release
cmake --build build --config Release

# Build for specific architecture
cmake -S . -B build-x86_64 -DCMAKE_OSX_ARCHITECTURES=x86_64
cmake --build build-x86_64 --config Release

cmake -S . -B build-arm64 -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build build-arm64 --config Release

# Create universal binary
lipo -create build-x86_64/toasty build-arm64/toasty -output toasty
```

### Installation

```bash
# Install to user bin directory
mkdir -p ~/bin
cp build/toasty ~/bin/
# Add ~/bin to PATH in ~/.zshrc or ~/.bash_profile

# Or install system-wide
sudo cp build/toasty /usr/local/bin/
```

## Notification Permissions

On first run, toasty will request notification permissions. The user must grant these permissions in System Preferences > Notifications > toasty.

To check permissions programmatically:
```objc
UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
[center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * settings) {
    if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
        // Permissions granted
    }
}];
```

## Focus Management

Unlike Windows, macOS doesn't require saving window handles. When a notification is clicked, toasty can activate the terminal application directly:

- Terminal.app (com.apple.Terminal)
- iTerm2 (com.googlecode.iterm2)
- WezTerm (com.github.wez.wezterm)

The `focus_saved_target()` function uses `NSWorkspace` to find and activate the terminal app.

## Hook Installation

Hooks work the same way as Windows, but with Unix-style paths:

### Claude Code Hook
```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "/usr/local/bin/toasty \"Task complete\" -t \"Claude Code\"",
        "timeout": 5000
      }]
    }]
  }
}
```

The hook installer automatically:
1. Creates config directories if they don't exist
2. Uses Unix-style paths (~/.claude, ~/.gemini)
3. Writes JSON with proper escaping

## Code Structure

```
main_mac.mm
├── Objective-C++ Helpers
│   ├── toNSString()      - Convert std::string to NSString
│   └── fromNSString()    - Convert NSString to std::string
│
├── File Operations
│   ├── readFile()        - Read JSON config files
│   ├── writeFile()       - Write JSON config files
│   └── expandPath()      - Expand ~ and $HOME
│
├── Notifications
│   ├── requestNotificationPermission() - Request user permissions
│   └── showNotification()              - Display notification
│
├── Hook Management
│   ├── installClaudeHook()
│   ├── installGeminiHook()
│   ├── installCopilotHook()
│   └── is*Installed()
│
└── main() - Entry point and argument parsing
```

## Troubleshooting

### Notifications not appearing

1. Check System Preferences > Notifications
2. Find "toasty" in the list
3. Ensure "Allow Notifications" is enabled
4. Set alert style to "Alerts" (not "Banners")

### Permission denied errors

The first time toasty runs, it requests permissions. If the user denies, they must manually enable in System Preferences.

### Click-to-focus not working

Unlike Windows, macOS notifications don't support custom activation schemes as easily. The current implementation activates the terminal app when any notification is clicked.

### Build errors

```bash
# Ensure Xcode Command Line Tools are installed
xcode-select --install

# Check CMake version
cmake --version  # Should be 3.20+

# Clean build
rm -rf build
cmake -S . -B build
cmake --build build
```

## Testing

```bash
# Basic test
./build/toasty "Test message"

# With title
./build/toasty "Test message" -t "Test Title"

# Check help
./build/toasty --help

# Test hook installation
./build/toasty --status
./build/toasty --install claude
./build/toasty --status
./build/toasty --uninstall
```

## Platform-Specific Code

The macOS version is completely separate from the Windows version:

- Windows: `main.cpp` (C++ with WinRT)
- macOS: `main_mac.mm` (Objective-C++)

CMakeLists.txt detects the platform and builds the appropriate version:

```cmake
if(WIN32)
    add_executable(toasty main.cpp resource.rc)
    target_link_libraries(toasty PRIVATE windowsapp ...)
elseif(APPLE)
    add_executable(toasty main_mac.mm)
    target_link_libraries(toasty PRIVATE 
        "-framework Foundation"
        "-framework UserNotifications"
        "-framework AppKit"
    )
endif()
```

## Future Enhancements

Potential improvements for the macOS version:

1. **Better icon support**: Bundle icons with the executable
2. **Custom notification actions**: Add buttons to notifications
3. **Persistent notifications**: Keep notifications visible until dismissed
4. **Better process detection**: Detect parent AI agent processes on macOS
5. **AppleScript integration**: Allow notifications from AppleScript
6. **Terminal.app integration**: Deep links to specific terminal windows

## License

MIT
