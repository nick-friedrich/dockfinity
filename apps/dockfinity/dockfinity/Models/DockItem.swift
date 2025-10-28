//
//  DockItem.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import Foundation
import SwiftData

enum DockItemType: String, Codable, Sendable {
    case app
    case folder
    case url
    case spacer
}

@Model
final class DockItem {
    var id: UUID
    var type: DockItemType
    var name: String
    var path: String // File path for apps/folders, URL string for web shortcuts
    var position: Int
    var customIconData: Data? // Optional custom icon, for future use
    var section: String = "apps" // "apps" or "others" - indicates which Dock section the item belongs to
    
    // Relationship
    var profile: Profile?
    
    init(type: DockItemType, name: String, path: String, position: Int, customIconData: Data? = nil, section: String = "apps") {
        self.id = UUID()
        self.type = type
        self.name = name
        self.path = path
        self.position = position
        self.customIconData = customIconData
        self.section = section
    }
}

