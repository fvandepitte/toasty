#pragma once

#include <string>

// Platform-agnostic interface for notifications
class Platform {
public:
    virtual ~Platform() = default;
    
    // Show a notification with title, message, and optional icon
    virtual bool show_notification(const std::wstring& title, 
                                   const std::wstring& message,
                                   const std::wstring& iconPath) = 0;
    
    // Register the application for notifications
    virtual bool register_app() = 0;
    
    // Check if the app is registered
    virtual bool is_registered() = 0;
    
    // Save a window/application reference for focus
    virtual bool save_focus_target(void* target) = 0;
    
    // Focus the saved window/application
    virtual bool focus_saved_target() = 0;
    
    // Install hooks for AI agents
    virtual bool install_claude_hook(const std::wstring& exePath) = 0;
    virtual bool install_gemini_hook(const std::wstring& exePath) = 0;
    virtual bool install_copilot_hook(const std::wstring& exePath) = 0;
    
    // Check if hooks are installed
    virtual bool is_claude_installed() = 0;
    virtual bool is_gemini_installed() = 0;
    virtual bool is_copilot_installed() = 0;
    
    // Uninstall hooks
    virtual bool uninstall_claude_hook() = 0;
    virtual bool uninstall_gemini_hook() = 0;
    virtual bool uninstall_copilot_hook() = 0;
    
    // Get home directory path
    virtual std::wstring get_home_directory() = 0;
    
    // Expand environment variables in path
    virtual std::wstring expand_env(const std::wstring& path) = 0;
    
    // Check if path exists
    virtual bool path_exists(const std::wstring& path) = 0;
};

// Factory function to create platform-specific instance
Platform* create_platform();
