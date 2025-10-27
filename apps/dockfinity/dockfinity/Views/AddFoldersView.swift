//
//  AddFoldersView.swift
//  dockfinity
//
//  Created by Nick Friedrich on 27.10.25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct FolderInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let iconData: Data?
    let isCommon: Bool // Whether this is a common/suggested folder
}

struct AddFoldersView: View {
    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var availableFolders: [FolderInfo] = []
    @State private var selectedFolderPaths: Set<String> = []
    @State private var initiallySelectedPaths: Set<String> = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingFilePicker = false
    
    var filteredFolders: [FolderInfo] {
        if searchText.isEmpty {
            return availableFolders
        }
        return availableFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Folders")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search folders...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Browse button
            HStack {
                Button(action: { showingFilePicker = true }) {
                    Label("Browse for Folder...", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("Tip: Add frequently used folders for quick access")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Folder list
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading folders...")
                    Spacer()
                }
            } else {
                List(filteredFolders) { folder in
                    HStack(spacing: 12) {
                        // Checkbox
                        Toggle(isOn: Binding(
                            get: { selectedFolderPaths.contains(folder.path) },
                            set: { isSelected in
                                if isSelected {
                                    selectedFolderPaths.insert(folder.path)
                                } else {
                                    selectedFolderPaths.remove(folder.path)
                                }
                            }
                        )) {
                            EmptyView()
                        }
                        .toggleStyle(.checkbox)
                        
                        // Folder icon
                        if let iconData = folder.iconData,
                           let nsImage = NSImage(data: iconData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .cornerRadius(6)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange.gradient)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                        }
                        
                        // Folder name
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(folder.name)
                                    .font(.body)
                                
                                // Badge for common folders
                                if folder.isCommon {
                                    Text("Common")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(folder.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            // Footer with action buttons
            HStack {
                let addedCount = selectedFolderPaths.subtracting(initiallySelectedPaths).count
                let removedCount = initiallySelectedPaths.subtracting(selectedFolderPaths).count
                
                if addedCount > 0 || removedCount > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        if addedCount > 0 {
                            Text("+\(addedCount) folder\(addedCount == 1 ? "" : "s") to add")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        if removedCount > 0 {
                            Text("-\(removedCount) folder\(removedCount == 1 ? "" : "s") to remove")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    Text("\(selectedFolderPaths.count) folder\(selectedFolderPaths.count == 1 ? "" : "s") selected")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Apply Changes") {
                    applyChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFolderPaths == initiallySelectedPaths)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleBrowsedFolder(result)
        }
        .task {
            // Initialize selected paths with folders already in profile
            initiallySelectedPaths = Set(profile.items.filter { $0.type == .folder }.map(\.path))
            selectedFolderPaths = initiallySelectedPaths
            
            await loadCommonFolders()
        }
    }
    
    private func loadCommonFolders() async {
        isLoading = true
        
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser.path
        
        // Define common folders
        let commonFolderPaths = [
            "/Applications",
            "\(homeDirectory)/Documents",
            "\(homeDirectory)/Downloads",
            "\(homeDirectory)/Desktop"
        ]
        
        var folders: [FolderInfo] = []
        
        // Add common folders
        for folderPath in commonFolderPaths {
            guard fileManager.fileExists(atPath: folderPath) else { continue }
            
            let folderURL = URL(fileURLWithPath: folderPath)
            let name = folderURL.lastPathComponent
            let iconData = getFolderIconData(for: folderPath)
            
            folders.append(FolderInfo(
                name: name,
                path: folderPath,
                iconData: iconData,
                isCommon: true
            ))
        }
        
        // Update UI on main thread
        await MainActor.run {
            self.availableFolders = folders
            self.isLoading = false
        }
    }
    
    private func getFolderIconData(for path: String) -> Data? {
        let icon = NSWorkspace.shared.icon(forFile: path)
        let targetSize = NSSize(width: 32, height: 32)
        let resizedIcon = NSImage(size: targetSize)
        resizedIcon.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: targetSize),
                 from: NSRect(origin: .zero, size: icon.size),
                 operation: .copy,
                 fraction: 1.0)
        resizedIcon.unlockFocus()
        
        if let tiffData = resizedIcon.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return pngData
        }
        return nil
    }
    
    private func handleBrowsedFolder(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Get the first URL (should only be one since allowsMultipleSelection is false)
            guard let url = urls.first else { return }
            
            // Ensure we have access to the file
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access selected folder")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let path = url.path
            let name = url.lastPathComponent
            
            // Check if folder is already in the list
            if availableFolders.contains(where: { $0.path == path }) {
                // Folder already exists, just select it
                selectedFolderPaths.insert(path)
            } else {
                // Add new folder to the list
                let iconData = getFolderIconData(for: path)
                let newFolder = FolderInfo(
                    name: name,
                    path: path,
                    iconData: iconData,
                    isCommon: false
                )
                
                // Insert at the end (after common folders)
                availableFolders.append(newFolder)
                
                // Automatically select it
                selectedFolderPaths.insert(path)
            }
            
        case .failure(let error):
            print("Error selecting folder: \(error.localizedDescription)")
        }
    }
    
    private func applyChanges() {
        // Find folders to add (selected but not initially selected)
        let foldersToAdd = selectedFolderPaths.subtracting(initiallySelectedPaths)
        
        // Find folders to remove (initially selected but not selected now)
        let foldersToRemove = initiallySelectedPaths.subtracting(selectedFolderPaths)
        
        // Remove folders
        if !foldersToRemove.isEmpty {
            let itemsToDelete = profile.items.filter { 
                $0.type == .folder && foldersToRemove.contains($0.path)
            }
            for item in itemsToDelete {
                modelContext.delete(item)
                print("➖ Removed \(item.name) from profile")
            }
        }
        
        // Add new folders
        if !foldersToAdd.isEmpty {
            let maxPosition = profile.items.map(\.position).max() ?? -1
            
            for (index, folderPath) in foldersToAdd.enumerated() {
                // Find the folder info
                guard let folderInfo = availableFolders.first(where: { $0.path == folderPath }) else {
                    continue
                }
                
                let dockItem = DockItem(
                    type: .folder,
                    name: folderInfo.name,
                    path: folderInfo.path,
                    position: maxPosition + 1 + index,
                    customIconData: folderInfo.iconData
                )
                dockItem.profile = profile
                modelContext.insert(dockItem)
                
                print("➕ Added \(folderInfo.name) to profile")
            }
        }
        
        // Reindex positions for remaining items
        let remainingItems = profile.items.sorted { $0.position < $1.position }
        for (index, item) in remainingItems.enumerated() {
            item.position = index
        }
        
        // Save changes
        do {
            try modelContext.save()
            if !foldersToAdd.isEmpty {
                print("✅ Added \(foldersToAdd.count) folder(s) to profile")
            }
            if !foldersToRemove.isEmpty {
                print("✅ Removed \(foldersToRemove.count) folder(s) from profile")
            }
        } catch {
            print("❌ Failed to apply changes: \(error)")
        }
    }
}

