//
//  DockStateManager.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import Foundation
import SwiftData
import Combine

enum DockStateError: LocalizedError {
    case contextUnavailable
    case emptyDockSnapshot
    case persistenceFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return "Model context is not attached."
        case .emptyDockSnapshot:
            return "Unable to read Dock items. Check accessibility permissions and try again."
        case .persistenceFailed(let message):
            return "Failed to save Dock data: \(message)"
        }
    }
}

@MainActor
class DockStateManager: ObservableObject {
    private var modelContext: ModelContext?
    private let dockUtilService = DockUtilService.shared
    
    @Published var currentProfileID: UUID?
    
    private let firstLaunchKey = "DockFinity_HasLaunched"
    private let firstLaunchTimestampKey = "DockFinity_FirstLaunchTimestamp"
    private let currentProfileKey = "DockFinity_CurrentProfile"
    
    init(context: ModelContext? = nil) {
        self.modelContext = context
        self.currentProfileID = Self.loadCurrentProfileID()
    }
    
    func attach(context: ModelContext) {
        self.modelContext = context
    }
    
    private func requireContext(_ function: StaticString = #function) throws -> ModelContext {
        guard let modelContext else {
            print("❌ DockStateManager context missing in \(function)")
            throw DockStateError.contextUnavailable
        }
        return modelContext
    }
    
    // MARK: - First Launch
    
    var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: firstLaunchKey)
    }
    
    func markFirstLaunchComplete() {
        UserDefaults.standard.set(true, forKey: firstLaunchKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: firstLaunchTimestampKey)
    }
    
    /// Safer first-launch initialization: only creates default profile if database is truly empty
    func ensureInitialData() async throws {
        let context = try requireContext()
        // Fetch ALL profiles to check if database is empty
        let allProfilesDescriptor = FetchDescriptor<Profile>()
        let existingProfiles = try context.fetch(allProfilesDescriptor)
        
        if existingProfiles.isEmpty {
            // Database is completely empty - create default profile
            print("📦 Database empty - creating default profile")
            _ = try await createDefaultProfile()
            markFirstLaunchComplete()
        } else {
            // Profiles exist - mark as initialized to prevent future overwrites
            print("✅ Found \(existingProfiles.count) existing profile(s) - skipping initialization")
            markFirstLaunchComplete()
            
            // If no current profile is set, set it to the first available profile
            if currentProfileID == nil, let firstProfile = existingProfiles.first {
                setCurrentProfile(firstProfile)
                print("📌 Set current profile to: \(firstProfile.name)")
            }
        }
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
        let context = try requireContext()
        print("🚀 Creating default profile...")
        
        // First check: Do ANY profiles exist at all?
        let allProfilesDescriptor = FetchDescriptor<Profile>()
        let allProfiles = try context.fetch(allProfilesDescriptor)
        
        if !allProfiles.isEmpty {
            print("⚠️ Profiles already exist - aborting default profile creation")
            print("   Found \(allProfiles.count) existing profile(s)")
            // Use the first one (or first default)
            let defaultProfile = allProfiles.first(where: { $0.isDefault }) ?? allProfiles[0]
            setCurrentProfile(defaultProfile)
            return defaultProfile
        }
        
        // Second check: Specifically look for default profiles
        let defaultDescriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.isDefault == true }
        )
        let existingDefaults = try context.fetch(defaultDescriptor)
        
        if !existingDefaults.isEmpty {
            print("⚠️ Default profile already exists")
            let defaultProfile = existingDefaults[0]
            setCurrentProfile(defaultProfile)
            return defaultProfile
        }
        
        // Read current Dock state
        let currentDockItems = try await dockUtilService.readCurrentDock()
        guard !currentDockItems.isEmpty else {
            throw DockStateError.emptyDockSnapshot
        }
        print("📊 Read \(currentDockItems.count) items from Dock")
        
        // Create Default profile
        let defaultProfile = Profile(name: "Default", isDefault: true, sortOrder: 0)
        context.insert(defaultProfile)
        
        // Add items to the profile
        for (index, itemInfo) in currentDockItems.enumerated() {
            let dockItem = DockItem(
                type: itemInfo.type,
                name: itemInfo.name,
                path: itemInfo.path,
                position: index,
                customIconData: itemInfo.iconData,
                section: itemInfo.section
            )
            dockItem.profile = defaultProfile
            context.insert(dockItem)
            print("  ➕ Added: \(itemInfo.name) (section: \(itemInfo.section))")
        }
        
        do {
            try context.save()
        } catch {
            context.delete(defaultProfile)
            throw DockStateError.persistenceFailed(error.localizedDescription)
        }
        setCurrentProfile(defaultProfile)
        
        print("✅ Default profile created with \(currentDockItems.count) items")
        return defaultProfile
    }
    
    // MARK: - Refresh Profile from Dock
    
    func refreshProfileFromDock(_ profile: Profile) async throws {
        let context = try requireContext()
        // Read current Dock state
        let currentDockItems = try await dockUtilService.readCurrentDock()
        guard !currentDockItems.isEmpty else {
            throw DockStateError.emptyDockSnapshot
        }
        
        try context.transaction {
            // Remove existing items from profile
            for item in profile.items {
                context.delete(item)
            }
            
            // Add new items
            for (index, itemInfo) in currentDockItems.enumerated() {
                let dockItem = DockItem(
                    type: itemInfo.type,
                    name: itemInfo.name,
                    path: itemInfo.path,
                    position: index,
                    customIconData: itemInfo.iconData,
                    section: itemInfo.section
                )
                dockItem.profile = profile
                context.insert(dockItem)
            }
            
            do {
                try context.save()
            } catch {
                throw DockStateError.persistenceFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Apply Profile
    
    func applyProfile(_ profile: Profile) async throws {
        let sortedItems = profile.items.sorted { $0.position < $1.position }
        try await dockUtilService.applyProfile(items: sortedItems)
        setCurrentProfile(profile)
    }
}
