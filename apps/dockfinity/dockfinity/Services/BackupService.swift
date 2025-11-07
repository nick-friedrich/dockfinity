//
//  BackupService.swift
//  dockfinity
//
//  Created by Nick Friedrich on 08.11.25.
//

import Foundation
import SwiftData

enum BackupError: LocalizedError {
    case emptyStore
    case invalidFile
    case persistenceFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyStore:
            return "There are no profiles to back up yet."
        case .invalidFile:
            return "The selected file is not a valid DockFinity backup."
        case .persistenceFailure(let message):
            return "Failed to restore backup: \(message)"
        }
    }
}

struct BackupDockItem: Codable {
    let id: UUID
    let type: DockItemType
    let name: String
    let path: String
    let position: Int
    let customIconData: Data?
    let section: String
}

struct BackupProfile: Codable {
    let id: UUID
    let name: String
    let creationDate: Date
    let isDefault: Bool
    let sortOrder: Int
    let items: [BackupDockItem]
}

struct DockFinityBackup: Codable {
    let version: String
    let exportedAt: Date
    let profileCount: Int
    let profiles: [BackupProfile]
}

@MainActor
final class BackupService {
    static let shared = BackupService()
    private init() {}
    
    func exportBackup(to url: URL, using context: ModelContext) throws {
        let descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\Profile.sortOrder)])
        let profiles = try context.fetch(descriptor)
        guard !profiles.isEmpty else {
            throw BackupError.emptyStore
        }
        
        let profilePayloads: [BackupProfile] = profiles.map { profile in
            let sortedItems = profile.items.sorted { $0.position < $1.position }
            let itemPayloads = sortedItems.map { item in
                BackupDockItem(
                    id: item.id,
                    type: item.type,
                    name: item.name,
                    path: item.path,
                    position: item.position,
                    customIconData: item.customIconData,
                    section: item.section
                )
            }
            
            return BackupProfile(
                id: profile.id,
                name: profile.name,
                creationDate: profile.creationDate,
                isDefault: profile.isDefault,
                sortOrder: profile.sortOrder,
                items: itemPayloads
            )
        }
        
        let payload = DockFinityBackup(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            exportedAt: Date(),
            profileCount: profilePayloads.count,
            profiles: profilePayloads
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }
    
    func importBackup(from url: URL, using context: ModelContext) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let backup = try? decoder.decode(DockFinityBackup.self, from: data) else {
            throw BackupError.invalidFile
        }
        
        try context.transaction {
            let existingProfiles = try context.fetch(FetchDescriptor<Profile>())
            for profile in existingProfiles {
                context.delete(profile)
            }
            
            for backupProfile in backup.profiles.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let profile = Profile(
                    id: backupProfile.id,
                    name: backupProfile.name,
                    creationDate: backupProfile.creationDate,
                    isDefault: backupProfile.isDefault,
                    sortOrder: backupProfile.sortOrder
                )
                context.insert(profile)
                
                for itemData in backupProfile.items.sorted(by: { $0.position < $1.position }) {
                    let item = DockItem(
                        id: itemData.id,
                        type: itemData.type,
                        name: itemData.name,
                        path: itemData.path,
                        position: itemData.position,
                        customIconData: itemData.customIconData,
                        section: itemData.section
                    )
                    item.profile = profile
                    context.insert(item)
                }
            }
            
            do {
                try context.save()
            } catch {
                throw BackupError.persistenceFailure(error.localizedDescription)
            }
        }
        
        // Rebuild current profile selection to match restored data
        let descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\Profile.sortOrder)])
        let restoredProfiles = try context.fetch(descriptor)
        if let selected = restoredProfiles.first(where: { $0.isDefault }) ?? restoredProfiles.first {
            let stateManager = DockStateManager(context: context)
            stateManager.setCurrentProfile(selected)
        } else {
            UserDefaults.standard.removeObject(forKey: "DockFinity_CurrentProfile")
        }
        
        return backup.profileCount
    }
}
