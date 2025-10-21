//
//  ProfileDetailView.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import SwiftUI
import SwiftData
import AppKit

struct ProfileDetailView: View {
    let profile: Profile
    @Binding var isRefreshing: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddApps = false
    
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
                            .contextMenu {
                                Button("Remove from Profile", role: .destructive) {
                                    deleteItem(item)
                                }
                            }
                    }
                    .onMove(perform: moveItems)
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(profile.name)
        .navigationSubtitle("\(sortedItems.count) item\(sortedItems.count == 1 ? "" : "s")")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddApps = true
                } label: {
                    Label("Add Apps", systemImage: "plus.app")
                }
                .labelStyle(.titleAndIcon)
                .help("Add applications to this profile")
            }
        }
        .sheet(isPresented: $showingAddApps) {
            AddAppsView(profile: profile)
        }
        .overlay {
            if isRefreshing {
                ProgressView("Refreshing from Dock...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var reorderedItems = sortedItems
        reorderedItems.move(fromOffsets: source, toOffset: destination)
        
        // Update position for all items
        for (index, item) in reorderedItems.enumerated() {
            item.position = index
        }
        
        // Save to SwiftData
        do {
            try modelContext.save()
            print("✅ Items reordered and saved")
        } catch {
            print("❌ Failed to save reordered items: \(error)")
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { sortedItems[$0] }
        
        // Delete items
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        
        // Update positions for remaining items
        let remainingItems = sortedItems.filter { item in
            !itemsToDelete.contains(where: { $0.id == item.id })
        }
        
        for (index, item) in remainingItems.enumerated() {
            item.position = index
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("✅ Removed \(itemsToDelete.count) item(s) from profile")
        } catch {
            print("❌ Failed to delete items: \(error)")
        }
    }
    
    private func deleteItem(_ item: DockItem) {
        // Find the index and delete using the existing function
        if let index = sortedItems.firstIndex(where: { $0.id == item.id }) {
            deleteItems(at: IndexSet(integer: index))
        }
    }
}

struct DockItemRow: View {
    let item: DockItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Item icon - show actual icon if available, otherwise show placeholder
            Group {
                if let iconData = item.customIconData,
                   let nsImage = NSImage(data: iconData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } else {
                    // Fallback to placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(itemColor.gradient)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: itemIcon)
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                }
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

