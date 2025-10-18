//
//  DockStateManager.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import Foundation
import SwiftData
import Combine

@MainActor
class DockStateManager: ObservableObject {
    private let modelContext: ModelContext
    private let dockUtilService = DockUtilService.shared
    
    @Published var currentProfileID: UUID?
    
    private let firstLaunchKey = "DockFinity_HasLaunched"
    private let currentProfileKey = "DockFinity_CurrentProfile"
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.currentProfileID = Self.loadCurrentProfileID()
    }
    
    // MARK: - First Launch
    
    var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: firstLaunchKey)
    }
    
    func markFirstLaunchComplete() {
        UserDefaults.standard.set(true, forKey: firstLaunchKey)
    }
    
    // MARK: - Current Profile Tracking
    
    static func loadCurrentProfileID() -> UUID? {
        guard let uuidString = UserDefaults.standard.string(forKey: "DockFinity_CurrentProfile"),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return uuid
    }
    
    func setCurrentProfile(_ profile: Profile) {
        currentProfileID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: currentProfileKey)
    }
    
    // MARK: - Default Profile Creation
    
    func createDefaultProfile() async throws -> Profile {
        // Read current Dock state
        let currentDockItems = try await dockUtilService.readCurrentDock()
        
        // Create Default profile
        let defaultProfile = Profile(name: "Default", isDefault: true, sortOrder: 0)
        modelContext.insert(defaultProfile)
        
        // Add items to the profile
        for (index, itemInfo) in currentDockItems.enumerated() {
            let dockItem = DockItem(
                type: itemInfo.type,
                name: itemInfo.name,
                path: itemInfo.path,
                position: index
            )
            dockItem.profile = defaultProfile
            modelContext.insert(dockItem)
        }
        
        try modelContext.save()
        setCurrentProfile(defaultProfile)
        
        return defaultProfile
    }
    
    // MARK: - Refresh Profile from Dock
    
    func refreshProfileFromDock(_ profile: Profile) async throws {
        // Read current Dock state
        let currentDockItems = try await dockUtilService.readCurrentDock()
        
        // Remove existing items from profile
        for item in profile.items {
            modelContext.delete(item)
        }
        
        // Add new items
        for (index, itemInfo) in currentDockItems.enumerated() {
            let dockItem = DockItem(
                type: itemInfo.type,
                name: itemInfo.name,
                path: itemInfo.path,
                position: index
            )
            dockItem.profile = profile
            modelContext.insert(dockItem)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Apply Profile
    
    func applyProfile(_ profile: Profile) async throws {
        try await dockUtilService.applyProfile(items: profile.items)
        setCurrentProfile(profile)
    }
}

