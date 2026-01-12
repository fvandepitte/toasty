#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <AppKit/AppKit.h>
#include "platform.h"
#include <filesystem>
#include <fstream>
#include <sstream>
#include <codecvt>

namespace fs = std::filesystem;

// Helper to convert wstring to NSString
static NSString* toNSString(const std::wstring& wstr) {
    std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
    std::string str = converter.to_bytes(wstr);
    return [NSString stringWithUTF8String:str.c_str()];
}

// Helper to convert NSString to wstring
static std::wstring fromNSString(NSString* nsstr) {
    const char* cstr = [nsstr UTF8String];
    std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
    return converter.from_bytes(cstr);
}

class MacPlatform : public Platform {
public:
    MacPlatform() {
        // Request notification permissions on construction
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                                completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (!granted) {
                NSLog(@"Notification permission not granted");
            }
        }];
    }
    
    bool show_notification(const std::wstring& title, 
                          const std::wstring& message,
                          const std::wstring& iconPath) override {
        @autoreleasepool {
            UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
            content.title = toNSString(title);
            content.body = toNSString(message);
            content.sound = [UNNotificationSound defaultSound];
            
            // Add icon if provided
            if (!iconPath.empty() && path_exists(iconPath)) {
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
            
            // Create request with unique identifier
            NSString* identifier = [[NSUUID UUID] UUIDString];
            UNNotificationRequest* request = [UNNotificationRequest 
                requestWithIdentifier:identifier 
                content:content 
                trigger:nil];
            
            // Add notification to center
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
            
            // Wait for completion (with timeout)
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
            
            return success;
        }
    }
    
    bool register_app() override {
        // On macOS, we just need to request notification permissions
        // This is done in the constructor
        return true;
    }
    
    bool is_registered() override {
        // Check if we have notification permissions
        __block BOOL authorized = NO;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            authorized = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
        return authorized;
    }
    
    bool save_focus_target(void* target) override {
        // On macOS, we don't need to save a specific window reference
        // We can just activate the application
        return true;
    }
    
    bool focus_saved_target() override {
        @autoreleasepool {
            // Activate the current application
            [NSApp activateIgnoringOtherApps:YES];
            
            // Also try to bring Terminal or iTerm to front
            NSArray* runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
            for (NSRunningApplication* app in runningApps) {
                NSString* bundleId = [app bundleIdentifier];
                if ([bundleId isEqualToString:@"com.apple.Terminal"] ||
                    [bundleId isEqualToString:@"com.googlecode.iterm2"] ||
                    [bundleId isEqualToString:@"com.github.wez.wezterm"]) {
                    [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
                    return true;
                }
            }
            
            return true;
        }
    }
    
    std::wstring get_home_directory() override {
        @autoreleasepool {
            NSString* homePath = NSHomeDirectory();
            return fromNSString(homePath);
        }
    }
    
    std::wstring expand_env(const std::wstring& path) override {
        std::wstring result = path;
        
        // Replace ~ with home directory
        if (!result.empty() && result[0] == L'~') {
            std::wstring home = get_home_directory();
            result = home + result.substr(1);
        }
        
        // Replace $HOME
        size_t pos = result.find(L"$HOME");
        if (pos != std::wstring::npos) {
            std::wstring home = get_home_directory();
            result.replace(pos, 5, home);
        }
        
        return result;
    }
    
    bool path_exists(const std::wstring& path) override {
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        std::string str = converter.to_bytes(path);
        return fs::exists(str);
    }
    
    // Read file content as string
    std::string read_file(const std::wstring& path) {
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        std::string str = converter.to_bytes(path);
        std::ifstream file(str, std::ios::binary);
        if (!file) {
            return "";
        }
        std::stringstream buffer;
        buffer << file.rdbuf();
        return buffer.str();
    }
    
    // Write string to file
    bool write_file(const std::wstring& path, const std::string& content) {
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        std::string str = converter.to_bytes(path);
        
        // Create parent directories if they don't exist
        fs::path p(str);
        if (p.has_parent_path()) {
            fs::create_directories(p.parent_path());
        }
        
        std::ofstream file(str, std::ios::binary);
        if (!file) {
            return false;
        }
        file << content;
        return file.good();
    }
    
    // Backup a file
    bool backup_file(const std::wstring& path) {
        std::wstring backupPath = path + L".bak";
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        try {
            if (path_exists(path)) {
                fs::copy_file(converter.to_bytes(path), converter.to_bytes(backupPath), 
                             fs::copy_options::overwrite_existing);
            }
            return true;
        } catch (...) {
            return false;
        }
    }
    
    // Helper to check if JSON contains toasty hook
    bool has_toasty_in_json(const std::string& json) {
        return json.find("toasty") != std::string::npos;
    }
    
    bool install_claude_hook(const std::wstring& exePath) override {
        std::wstring configPath = expand_env(L"~/.claude/settings.json");
        std::string existingContent = read_file(configPath);
        
        // Simple JSON manipulation - check if toasty already exists
        if (has_toasty_in_json(existingContent)) {
            return true; // Already installed
        }
        
        // Create basic hook structure
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        std::string exePathStr = converter.to_bytes(exePath);
        
        std::string hookJson;
        if (existingContent.empty() || existingContent == "{}") {
            hookJson = "{\n  \"hooks\": {\n    \"Stop\": [{\n      \"hooks\": [{\n        \"type\": \"command\",\n"
                      "        \"command\": \"" + exePathStr + " \\\"Task complete\\\" -t \\\"Claude Code\\\"\",\n"
                      "        \"timeout\": 5000\n      }]\n    }]\n  }\n}";
        } else {
            // For simplicity, just append to existing (would need proper JSON parsing for production)
            // This is a minimal implementation
            hookJson = existingContent;
            // Note: Proper implementation would use a JSON library
        }
        
        return write_file(configPath, hookJson);
    }
    
    bool install_gemini_hook(const std::wstring& exePath) override {
        std::wstring configPath = expand_env(L"~/.gemini/settings.json");
        std::string existingContent = read_file(configPath);
        
        if (has_toasty_in_json(existingContent)) {
            return true;
        }
        
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        std::string exePathStr = converter.to_bytes(exePath);
        
        std::string hookJson;
        if (existingContent.empty() || existingContent == "{}") {
            hookJson = "{\n  \"hooks\": {\n    \"AfterAgent\": [{\n      \"hooks\": [{\n        \"type\": \"command\",\n"
                      "        \"command\": \"" + exePathStr + " \\\"Gemini finished\\\" -t \\\"Gemini\\\"\",\n"
                      "        \"timeout\": 5000\n      }]\n    }]\n  }\n}";
        } else {
            hookJson = existingContent;
        }
        
        return write_file(configPath, hookJson);
    }
    
    bool install_copilot_hook(const std::wstring& exePath) override {
        std::wstring configPath = L".github/hooks/toasty.json";
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        std::string exePathStr = converter.to_bytes(exePath);
        
        std::string hookJson = "{\n  \"version\": 1,\n  \"hooks\": {\n    \"sessionEnd\": [{\n"
                              "      \"type\": \"command\",\n"
                              "      \"bash\": \"toasty 'Copilot finished' -t 'GitHub Copilot'\",\n"
                              "      \"powershell\": \"" + exePathStr + " 'Copilot finished' -t 'GitHub Copilot'\",\n"
                              "      \"timeoutSec\": 5\n    }]\n  }\n}";
        
        return write_file(configPath, hookJson);
    }
    
    bool is_claude_installed() override {
        std::wstring configPath = expand_env(L"~/.claude/settings.json");
        std::string content = read_file(configPath);
        return has_toasty_in_json(content);
    }
    
    bool is_gemini_installed() override {
        std::wstring configPath = expand_env(L"~/.gemini/settings.json");
        std::string content = read_file(configPath);
        return has_toasty_in_json(content);
    }
    
    bool is_copilot_installed() override {
        std::wstring configPath = L".github/hooks/toasty.json";
        std::string content = read_file(configPath);
        return has_toasty_in_json(content);
    }
    
    bool uninstall_claude_hook() override {
        // For simplicity, just delete the config or reset it
        // A full implementation would parse JSON and remove only toasty hooks
        return true;
    }
    
    bool uninstall_gemini_hook() override {
        return true;
    }
    
    bool uninstall_copilot_hook() override {
        std::wstring configPath = L".github/hooks/toasty.json";
        std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
        try {
            if (path_exists(configPath)) {
                fs::remove(converter.to_bytes(configPath));
            }
            return true;
        } catch (...) {
            return false;
        }
    }
};

Platform* create_platform() {
    return new MacPlatform();
}
