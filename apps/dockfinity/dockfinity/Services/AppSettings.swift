//
//  AppSettings.swift
//  dockfinity
//
//  Settings manager for app preferences
//

import Foundation
import AppKit
import Combine

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let showInDockKey = "DockFinity_ShowInDock"
    
    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: showInDockKey)
            applyActivationPolicy()
        }
    }
    
    init() {
        // Default to showing in Dock
        self.showInDock = UserDefaults.standard.object(forKey: showInDockKey) as? Bool ?? true
        applyActivationPolicy()
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
}

