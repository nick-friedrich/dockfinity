//
//  AppSettings.swift
//  dockfinity
//
//  Settings manager for app preferences
//

import Foundation
import AppKit
import Combine
import ServiceManagement

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let showInDockKey = "DockFinity_ShowInDock"
    private let launchAtLoginKey = "DockFinity_LaunchAtLogin"
    
    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: showInDockKey)
            applyActivationPolicy()
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: launchAtLoginKey)
            setLaunchAtLogin(launchAtLogin)
        }
    }
    
    init() {
        // Default to showing in Dock
        self.showInDock = UserDefaults.standard.object(forKey: showInDockKey) as? Bool ?? true
        
        // Check current login item status
        let loginItemEnabled = SMAppService.mainApp.status == .enabled
        self.launchAtLogin = UserDefaults.standard.object(forKey: launchAtLoginKey) as? Bool ?? loginItemEnabled
        
        applyActivationPolicy()
        
        // Ensure login item state matches preference
        if launchAtLogin != loginItemEnabled {
            setLaunchAtLogin(launchAtLogin)
        }
    }
    
    /// Apply the appropriate activation policy based on settings
    func applyActivationPolicy() {
        if showInDock {
            // Show in Dock - regular app
            NSApp.setActivationPolicy(.regular)
        } else {
            // Menu bar only - accessory app (no Dock icon)
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    /// Set launch at login preference
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    // Already enabled
                    return
                }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    // Already disabled
                    return
                }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}

