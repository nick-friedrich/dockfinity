//
//  ContentView.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dockStateManager: DockStateManager
    
    @State private var selectedProfile: Profile?
    @State private var showingNewProfile = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init(modelContext: ModelContext) {
        _dockStateManager = StateObject(wrappedValue: DockStateManager(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationSplitView() {
            ProfileListView(
                selectedProfile: $selectedProfile,
                showingNewProfile: $showingNewProfile,
                currentProfileID: dockStateManager.currentProfileID,
                onApply: applyProfile,
                onRefresh: refreshProfile,
                onDuplicate: duplicateProfile
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            if let selectedProfile {
                ProfileDetailView(
                    profile: selectedProfile,
                    isRefreshing: $isRefreshing
                )
                .id(selectedProfile.id)
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            Task {
                                await refreshProfile(selectedProfile)
                            }
                        } label: {
                            Label("Refresh from Dock", systemImage: "arrow.clockwise")
                        }
                        .labelStyle(.titleAndIcon)
                        .help("Update this profile with the current Dock items")
                        .disabled(isRefreshing)
                        
                        Button {
                            Task {
                                await applyProfile(selectedProfile)
                            }
                        } label: {
                            Label("Apply to Dock", systemImage: "checkmark.circle")
                        }
                        .labelStyle(.titleAndIcon)
                        .help("Apply this profile's items to your Dock")
                        .disabled(isRefreshing)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Profile",
                    systemImage: "sidebar.left",
                    description: Text("Choose a profile from the sidebar to view its Dock items")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 500)
        .sheet(isPresented: $showingNewProfile) {
            NavigationStack {
                ProfileFormView { newProfile in
                    selectedProfile = newProfile
                }
            }
        }
        .alert("Error", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    private func applyProfile(_ profile: Profile) async {
        do {
            try await dockStateManager.applyProfile(profile)
        } catch {
            errorMessage = "Failed to apply profile: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    @MainActor
    private func refreshProfile(_ profile: Profile) async {
        isRefreshing = true
        
        do {
            try await dockStateManager.refreshProfileFromDock(profile)
        } catch {
            errorMessage = "Failed to refresh profile: \(error.localizedDescription)"
            showingError = true
        }
        
        isRefreshing = false
    }
    
    private func duplicateProfile(_ profile: Profile) {
        let duplicate = Profile(
            name: "\(profile.name) Copy",
            isDefault: false,
            sortOrder: profile.sortOrder + 1
        )
        modelContext.insert(duplicate)
        
        for item in profile.items {
            let duplicateItem = DockItem(
                type: item.type,
                name: item.name,
                path: item.path,
                position: item.position,
                customIconData: item.customIconData
            )
            duplicateItem.profile = duplicate
            modelContext.insert(duplicateItem)
        }
        
        try? modelContext.save()
        selectedProfile = duplicate
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Profile.self, DockItem.self, configurations: config)
    let context = container.mainContext
    
    // Create sample profile
    let profile = Profile(name: "Work", isDefault: false, sortOrder: 0)
    context.insert(profile)
    
    let item1 = DockItem(type: .app, name: "Safari", path: "/Applications/Safari.app", position: 0)
    item1.profile = profile
    context.insert(item1)
    
    let item2 = DockItem(type: .app, name: "Mail", path: "/Applications/Mail.app", position: 1)
    item2.profile = profile
    context.insert(item2)
    
    return ContentView(modelContext: context)
        .modelContainer(container)
}
