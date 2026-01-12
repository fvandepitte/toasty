#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <AppKit/AppKit.h>
#include <iostream>
#include <string>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <codecvt>
#include <locale>
#include <mach-o/dyld.h>

namespace fs = std::filesystem;

// Helper to convert string to NSString
static NSString* toNSString(const std::string& str) {
    return [NSString stringWithUTF8String:str.c_str()];
}

// Helper to convert NSString to string
static std::string fromNSString(NSString* nsstr) {
    return std::string([nsstr UTF8String]);
}

// Simple argument parsing
struct Args {
    std::string message;
    std::string title = "Notification";
    std::string iconPath;
    std::string appPreset;
    bool help = false;
    bool install = false;
    bool uninstall = false;
    bool status = false;
    std::string installAgent;
};

Args parseArgs(int argc, char* argv[]) {
    Args args;
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "-h" || arg == "--help") {
            args.help = true;
        } else if (arg == "-t" || arg == "--title") {
            if (i + 1 < argc) {
                args.title = argv[++i];
            }
        } else if (arg == "--app") {
            if (i + 1 < argc) {
                args.appPreset = argv[++i];
            }
        } else if (arg == "-i" || arg == "--icon") {
            if (i + 1 < argc) {
                args.iconPath = argv[++i];
            }
        } else if (arg == "--install") {
            args.install = true;
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                args.installAgent = argv[++i];
            }
        } else if (arg == "--uninstall") {
            args.uninstall = true;
        } else if (arg == "--status") {
            args.status = true;
        } else if (arg[0] != '-' && args.message.empty()) {
            args.message = arg;
        }
    }
    
    return args;
}

void printUsage() {
    std::cout << "toasty - macOS notification CLI\n\n"
              << "Usage:\n"
              << "  toasty <message> [options]\n"
              << "  toasty --install [agent]\n"
              << "  toasty --uninstall\n"
              << "  toasty --status\n\n"
              << "Options:\n"
              << "  -t, --title <text>   Set notification title (default: \"Notification\")\n"
              << "  --app <name>         Use AI CLI preset (claude, copilot, gemini, codex, cursor)\n"
              << "  -i, --icon <path>    Custom icon path (PNG recommended)\n"
              << "  -h, --help           Show this help\n"
              << "  --install [agent]    Install hooks for AI CLI agents (claude, gemini, copilot, or all)\n"
              << "  --uninstall          Remove hooks from all AI CLI agents\n"
              << "  --status             Show installation status\n\n"
              << "Examples:\n"
              << "  toasty \"Build completed\"\n"
              << "  toasty \"Task done\" -t \"Custom Title\"\n"
              << "  toasty \"Analysis complete\" --app claude\n"
              << "  toasty --install\n"
              << "  toasty --status\n";
}

std::string getHomeDirectory() {
    NSString* homePath = NSHomeDirectory();
    return fromNSString(homePath);
}

std::string expandPath(const std::string& path) {
    std::string result = path;
    
    // Replace ~ with home directory
    if (!result.empty() && result[0] == '~') {
        result = getHomeDirectory() + result.substr(1);
    }
    
    // Replace $HOME
    size_t pos = result.find("$HOME");
    if (pos != std::string::npos) {
        result.replace(pos, 5, getHomeDirectory());
    }
    
    return result;
}

bool pathExists(const std::string& path) {
    return fs::exists(path);
}

std::string readFile(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) return "";
    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

bool writeFile(const std::string& path, const std::string& content) {
    fs::path p(path);
    if (p.has_parent_path()) {
        fs::create_directories(p.parent_path());
    }
    
    std::ofstream file(path, std::ios::binary);
    if (!file) return false;
    file << content;
    return file.good();
}

std::string getExePath() {
    char path[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) == 0) {
        return std::string(path);
    }
    return "";
}

bool detectClaude() {
    return pathExists(expandPath("~/.claude"));
}

bool detectGemini() {
    return pathExists(expandPath("~/.gemini"));
}

bool detectCopilot() {
    return pathExists(".github/hooks") || pathExists(".github");
}

bool hasToastyInJson(const std::string& json) {
    return json.find("toasty") != std::string::npos;
}

bool installClaudeHook(const std::string& exePath) {
    std::string configPath = expandPath("~/.claude/settings.json");
    std::string existingContent = readFile(configPath);
    
    if (hasToastyInJson(existingContent)) {
        return true;
    }
    
    std::string hookJson = 
        "{\n"
        "  \"hooks\": {\n"
        "    \"Stop\": [{\n"
        "      \"hooks\": [{\n"
        "        \"type\": \"command\",\n"
        "        \"command\": \"" + exePath + " \\\"Task complete\\\" -t \\\"Claude Code\\\"\",\n"
        "        \"timeout\": 5000\n"
        "      }]\n"
        "    }]\n"
        "  }\n"
        "}";
    
    return writeFile(configPath, hookJson);
}

bool installGeminiHook(const std::string& exePath) {
    std::string configPath = expandPath("~/.gemini/settings.json");
    std::string existingContent = readFile(configPath);
    
    if (hasToastyInJson(existingContent)) {
        return true;
    }
    
    std::string hookJson = 
        "{\n"
        "  \"hooks\": {\n"
        "    \"AfterAgent\": [{\n"
        "      \"hooks\": [{\n"
        "        \"type\": \"command\",\n"
        "        \"command\": \"" + exePath + " \\\"Gemini finished\\\" -t \\\"Gemini\\\"\",\n"
        "        \"timeout\": 5000\n"
        "      }]\n"
        "    }]\n"
        "  }\n"
        "}";
    
    return writeFile(configPath, hookJson);
}

bool installCopilotHook(const std::string& exePath) {
    std::string hookJson = 
        "{\n"
        "  \"version\": 1,\n"
        "  \"hooks\": {\n"
        "    \"sessionEnd\": [{\n"
        "      \"type\": \"command\",\n"
        "      \"bash\": \"" + exePath + " 'Copilot finished' -t 'GitHub Copilot'\",\n"
        "      \"powershell\": \"" + exePath + " 'Copilot finished' -t 'GitHub Copilot'\",\n"
        "      \"timeoutSec\": 5\n"
        "    }]\n"
        "  }\n"
        "}";
    
    return writeFile(".github/hooks/toasty.json", hookJson);
}

bool isClaudeInstalled() {
    return hasToastyInJson(readFile(expandPath("~/.claude/settings.json")));
}

bool isGeminiInstalled() {
    return hasToastyInJson(readFile(expandPath("~/.gemini/settings.json")));
}

bool isCopilotInstalled() {
    return hasToastyInJson(readFile(".github/hooks/toasty.json"));
}

bool uninstallCopilotHook() {
    try {
        if (pathExists(".github/hooks/toasty.json")) {
            fs::remove(".github/hooks/toasty.json");
        }
        return true;
    } catch (...) {
        return false;
    }
}

void showStatus() {
    std::cout << "Installation status:\n\n";
    std::cout << "Detected agents:\n";
    std::cout << "  " << (detectClaude() ? "[x]" : "[ ]") << " Claude Code\n";
    std::cout << "  " << (detectGemini() ? "[x]" : "[ ]") << " Gemini CLI\n";
    std::cout << "  " << (detectCopilot() ? "[x]" : "[ ]") << " GitHub Copilot (in current repo)\n";
    std::cout << "\n";
    std::cout << "Installed hooks:\n";
    std::cout << "  " << (isClaudeInstalled() ? "[x]" : "[ ]") << " Claude Code\n";
    std::cout << "  " << (isGeminiInstalled() ? "[x]" : "[ ]") << " Gemini CLI\n";
    std::cout << "  " << (isCopilotInstalled() ? "[x]" : "[ ]") << " GitHub Copilot\n";
}

void handleInstall(const std::string& agent) {
    std::string exePath = getExePath();
    
    if (exePath.empty()) {
        std::cerr << "Error: Could not determine toasty executable path\n";
        return;
    }
    
    bool installAll = agent.empty() || agent == "all";
    bool explicitAgent = !installAll;
    bool installClaude = installAll || agent == "claude";
    bool installGemini = installAll || agent == "gemini";
    bool installCopilot = installAll || agent == "copilot";
    
    std::cout << "Detecting AI CLI agents...\n";
    std::cout << "  " << (detectClaude() ? "[x]" : "[ ]") << " Claude Code found\n";
    std::cout << "  " << (detectGemini() ? "[x]" : "[ ]") << " Gemini CLI found\n";
    std::cout << "  " << (detectCopilot() ? "[x]" : "[ ]") << " GitHub Copilot (in current repo)\n";
    std::cout << "\n";
    
    std::cout << "Installing toasty hooks...\n";
    
    bool anyInstalled = false;
    
    if (installClaude && (detectClaude() || explicitAgent)) {
        if (installClaudeHook(exePath)) {
            std::cout << "  [x] Claude Code: Added Stop hook\n";
            anyInstalled = true;
        } else {
            std::cout << "  [ ] Claude Code: Failed to install\n";
        }
    }
    
    if (installGemini && (detectGemini() || explicitAgent)) {
        if (installGeminiHook(exePath)) {
            std::cout << "  [x] Gemini CLI: Added AfterAgent hook\n";
            anyInstalled = true;
        } else {
            std::cout << "  [ ] Gemini CLI: Failed to install\n";
        }
    }
    
    if (installCopilot && (detectCopilot() || explicitAgent)) {
        if (installCopilotHook(exePath)) {
            std::cout << "  [x] GitHub Copilot: Added sessionEnd hook\n";
            std::cout << "      Note: This is repo-level only, not global\n";
            anyInstalled = true;
        } else {
            std::cout << "  [ ] GitHub Copilot: Failed to install\n";
        }
    }
    
    if (anyInstalled) {
        std::cout << "\nDone! You'll get notifications when AI agents finish.\n";
    } else {
        std::cout << "\nNo agents were installed. Check detection status above.\n";
    }
}

void handleUninstall() {
    std::cout << "Removing toasty hooks...\n";
    
    bool anyUninstalled = false;
    
    if (isCopilotInstalled()) {
        if (uninstallCopilotHook()) {
            std::cout << "  [x] GitHub Copilot: Removed hooks\n";
            anyUninstalled = true;
        } else {
            std::cout << "  [ ] GitHub Copilot: Failed to remove\n";
        }
    }
    
    if (anyUninstalled) {
        std::cout << "\nDone! Hooks have been removed.\n";
    } else {
        std::cout << "\nNo hooks were installed.\n";
    }
}

bool requestNotificationPermission() {
    @autoreleasepool {
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        
        __block BOOL granted = NO;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                                completionHandler:^(BOOL wasGranted, NSError * _Nullable error) {
            granted = wasGranted;
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        return granted;
    }
}

bool showNotification(const std::string& title, const std::string& message, const std::string& iconPath) {
    @autoreleasepool {
        UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
        content.title = toNSString(title);
        content.body = toNSString(message);
        content.sound = [UNNotificationSound defaultSound];
        
        // Add icon if provided
        if (!iconPath.empty() && pathExists(iconPath)) {
            NSString* iconPathNS = toNSString(iconPath);
            NSURL* iconURL = [NSURL fileURLWithPath:iconPathNS];
            
            NSError* error = nil;
            UNNotificationAttachment* attachment = [UNNotificationAttachment 
                attachmentWithIdentifier:@"icon" 
                URL:iconURL 
                options:nil 
                error:&error];
            
            if (attachment && !error) {
                content.attachments = @[attachment];
            }
        }
        
        // Create request
        NSString* identifier = [[NSUUID UUID] UUIDString];
        UNNotificationRequest* request = [UNNotificationRequest 
            requestWithIdentifier:identifier 
            content:content 
            trigger:nil];
        
        // Add notification
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        __block BOOL success = NO;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error showing notification: %@", error);
                success = NO;
            } else {
                success = YES;
            }
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
        return success;
    }
}

int main(int argc, char* argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printUsage();
            return 0;
        }
        
        Args args = parseArgs(argc, argv);
        
        if (args.help) {
            printUsage();
            return 0;
        }
        
        if (args.status) {
            showStatus();
            return 0;
        }
        
        if (args.install) {
            handleInstall(args.installAgent);
            return 0;
        }
        
        if (args.uninstall) {
            handleUninstall();
            return 0;
        }
        
        if (args.message.empty()) {
            std::cerr << "Error: Message is required.\n";
            printUsage();
            return 1;
        }
        
        // Request permission if needed
        requestNotificationPermission();
        
        // Show notification
        if (showNotification(args.title, args.message, args.iconPath)) {
            return 0;
        } else {
            std::cerr << "Failed to show notification. Please check System Preferences > Notifications.\n";
            return 1;
        }
    }
}
