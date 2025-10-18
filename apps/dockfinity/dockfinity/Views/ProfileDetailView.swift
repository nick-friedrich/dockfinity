//
//  ProfileDetailView.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import SwiftUI
import SwiftData

struct ProfileDetailView: View {
    let profile: Profile
    @Binding var isRefreshing: Bool
    
    var sortedItems: [DockItem] {
        profile.items.sorted { $0.position < $1.position }
    }
    
    var body: some View {
        Group {
            if sortedItems.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("This profile doesn't have any Dock items yet.\nRefresh from the current Dock to populate it.")
                )
            } else {
                List {
                    ForEach(sortedItems) { item in
                        DockItemRow(item: item)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(profile.name)
        .navigationSubtitle("\(sortedItems.count) item\(sortedItems.count == 1 ? "" : "s")")
        .overlay {
            if isRefreshing {
                ProgressView("Refreshing from Dock...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }
}

struct DockItemRow: View {
    let item: DockItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Item icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(itemColor.gradient)
                    .frame(width: 40, height: 40)
                
                Image(systemName: itemIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Item type badge
            Text(item.type.rawValue.capitalized)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(itemColor.opacity(0.2))
                .foregroundColor(itemColor)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    private var itemIcon: String {
        switch item.type {
        case .app:
            return "app.fill"
        case .folder:
            return "folder.fill"
        case .url:
            return "link"
        case .spacer:
            return "space"
        }
    }
    
    private var itemColor: Color {
        switch item.type {
        case .app:
            return .blue
        case .folder:
            return .orange
        case .url:
            return .green
        case .spacer:
            return .gray
        }
    }
}

