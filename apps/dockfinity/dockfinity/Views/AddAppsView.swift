//
//  AddAppsView.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let iconData: Data?
}

struct AddAppsView: View {
    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var availableApps: [AppInfo] = []
    @State private var selectedAppPaths: Set<String> = []
    @State private var initiallySelectedPaths: Set<String> = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingFilePicker = false
    
    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return availableApps
        }
        return availableApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Applications")
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
                TextField("Search applications...", text: $searchText)
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
                    Label("Browse for App...", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("Tip: Use Browse to add apps from any location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // App list
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading applications...")
                    Spacer()
                }
            } else {
                List(filteredApps) { app in
                    HStack(spacing: 12) {
                        // Checkbox
                        Toggle(isOn: Binding(
                            get: { selectedAppPaths.contains(app.path) },
                            set: { isSelected in
                                if isSelected {
                                    selectedAppPaths.insert(app.path)
                                } else {
                                    selectedAppPaths.remove(app.path)
                                }
                            }
                        )) {
                            EmptyView()
                        }
                        .toggleStyle(.checkbox)
                        
                        // App icon
                        if let iconData = app.iconData,
                           let nsImage = NSImage(data: iconData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .cornerRadius(6)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.gradient)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "app.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                        }
                        
                        // App name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.body)
                            
                            Text(app.path)
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
                let addedCount = selectedAppPaths.subtracting(initiallySelectedPaths).count
                let removedCount = initiallySelectedPaths.subtracting(selectedAppPaths).count
                
                if addedCount > 0 || removedCount > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        if addedCount > 0 {
                            Text("+\(addedCount) app\(addedCount == 1 ? "" : "s") to add")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        if removedCount > 0 {
                            Text("-\(removedCount) app\(removedCount == 1 ? "" : "s") to remove")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    Text("\(selectedAppPaths.count) app\(selectedAppPaths.count == 1 ? "" : "s") selected")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Apply Changes") {
                    applyChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAppPaths == initiallySelectedPaths)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleBrowsedApp(result)
        }
        .task {
            // Initialize selected paths with apps already in profile
            initiallySelectedPaths = Set(profile.items.map(\.path))
            selectedAppPaths = initiallySelectedPaths
            
            await loadAvailableApps()
        }
    }
    
    private func loadAvailableApps() async {
        isLoading = true
        
        // Get apps from /System/Applications, /Applications and ~/Applications
        let systemAppsPath = "/System/Applications"
        let applicationsPath = "/Applications"
        let userAppsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").path
        
        var apps: [AppInfo] = []
        var seenPaths = Set<String>() // Deduplicate apps by path
        
        // Scan all three directories recursively
        for appsPath in [systemAppsPath, applicationsPath, userAppsPath] {
            let foundApps = findAppsRecursively(in: appsPath, maxDepth: 4)
            for app in foundApps {
                if !seenPaths.contains(app.path) {
                    apps.append(app)
                    seenPaths.insert(app.path)
                }
            }
        }
        
        // Sort by name
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Update UI on main thread
        await MainActor.run {
            self.availableApps = apps
            self.isLoading = false
        }
    }
    
    private func findAppsRecursively(in path: String, maxDepth: Int, currentDepth: Int = 0) -> [AppInfo] {
        var apps: [AppInfo] = []
        
        // Stop if we've reached max depth
        guard currentDepth < maxDepth else { return apps }
        
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        // Use enumerator for efficient directory traversal
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        ) else { return apps }
        
        for case let itemURL as URL in enumerator {
            // Check if it's an .app bundle
            if itemURL.pathExtension == "app" {
                let path = itemURL.path
                let name = itemURL.deletingPathExtension().lastPathComponent
                
                // Get app icon
                if let iconData = getAppIconData(for: path) {
                    apps.append(AppInfo(name: name, path: path, iconData: iconData))
                } else {
                    apps.append(AppInfo(name: name, path: path, iconData: nil))
                }
                
                // Skip contents of .app bundles - don't descend into them
                enumerator.skipDescendants()
            }
            
            // Limit depth by tracking and skipping too-deep directories
            if let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
               let isDirectory = resourceValues.isDirectory,
               isDirectory {
                let itemPath = itemURL.path
                let depth = itemPath.components(separatedBy: "/").count - path.components(separatedBy: "/").count
                if depth >= maxDepth {
                    enumerator.skipDescendants()
                }
            }
        }
        
        return apps
    }
    
    private func getAppIconData(for path: String) -> Data? {
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
    
    private func handleBrowsedApp(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Get the first URL (should only be one since allowsMultipleSelection is false)
            guard let url = urls.first else { return }
            
            // Ensure we have access to the file
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access selected app")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let path = url.path
            let name = url.deletingPathExtension().lastPathComponent
            
            // Check if app is already in the list
            if availableApps.contains(where: { $0.path == path }) {
                // App already exists, just select it
                selectedAppPaths.insert(path)
            } else {
                // Add new app to the list
                let iconData = getAppIconData(for: path)
                let newApp = AppInfo(name: name, path: path, iconData: iconData)
                
                // Insert and re-sort
                availableApps.append(newApp)
                availableApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                
                // Automatically select it
                selectedAppPaths.insert(path)
            }
            
        case .failure(let error):
            print("Error selecting app: \(error.localizedDescription)")
        }
    }
    
    private func applyChanges() {
        // Find apps to add (selected but not initially selected)
        let appsToAdd = selectedAppPaths.subtracting(initiallySelectedPaths)
        
        // Find apps to remove (initially selected but not selected now)
        let appsToRemove = initiallySelectedPaths.subtracting(selectedAppPaths)
        
        // Remove apps
        if !appsToRemove.isEmpty {
            let itemsToDelete = profile.items.filter { appsToRemove.contains($0.path) }
            for item in itemsToDelete {
                modelContext.delete(item)
                print("➖ Removed \(item.name) from profile")
            }
        }
        
        // Add new apps
        if !appsToAdd.isEmpty {
            let maxPosition = profile.items.map(\.position).max() ?? -1
            
            for (index, appPath) in appsToAdd.enumerated() {
                // Find the app info
                guard let appInfo = availableApps.first(where: { $0.path == appPath }) else {
                    continue
                }
                
                let dockItem = DockItem(
                    type: .app,
                    name: appInfo.name,
                    path: appInfo.path,
                    position: maxPosition + 1 + index,
                    customIconData: appInfo.iconData
                )
                dockItem.profile = profile
                modelContext.insert(dockItem)
                
                print("➕ Added \(appInfo.name) to profile")
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
            if !appsToAdd.isEmpty {
                print("✅ Added \(appsToAdd.count) app(s) to profile")
            }
            if !appsToRemove.isEmpty {
                print("✅ Removed \(appsToRemove.count) app(s) from profile")
            }
        } catch {
            print("❌ Failed to apply changes: \(error)")
        }
    }
}

