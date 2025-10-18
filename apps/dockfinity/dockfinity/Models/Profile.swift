//
//  Profile.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import Foundation
import SwiftData

@Model
final class Profile: Sendable {
    var id: UUID
    var name: String
    var creationDate: Date
    var isDefault: Bool
    var sortOrder: Int
    
    // Relationship
    @Relationship(deleteRule: .cascade, inverse: \DockItem.profile)
    var items: [DockItem]
    
    init(name: String, isDefault: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.creationDate = Date()
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.items = []
    }
}

