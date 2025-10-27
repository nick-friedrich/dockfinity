//
//  dockfinityApp.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import SwiftUI
import SwiftData

@main
struct dockfinityApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Profile.self,
            DockItem.self,
        ])
        
        // Configure with CloudKit support
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @StateObject private var appSettings = AppSettings.shared
    @State private var isInitialized = false

    var body: some Scene {
        WindowGroup(id: "main") {
            if isInitialized {
                ContentView(modelContext: sharedModelContainer.mainContext)
                    .modelContainer(sharedModelContainer)
                    .environmentObject(appSettings)
            } else {
                ProgressView("Initializing DockFinity...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await initializeApp()
                    }
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView(appSettings: appSettings)
        }
        
        MenuBarExtra("DockFinity", systemImage: "dock.rectangle") {
            if isInitialized {
                MenuBarView(modelContext: sharedModelContainer.mainContext)
                    .modelContainer(sharedModelContainer)
                    .environmentObject(appSettings)
            } else {
                Text("Initializing...")
                    .foregroundColor(.secondary)
            }
        }
        .menuBarExtraStyle(.menu)
    }
    
    // MARK: - First Launch Initialization
    
    @MainActor
    private func initializeApp() async {
        let context = sharedModelContainer.mainContext
        let stateManager = DockStateManager(modelContext: context)
        
        if stateManager.isFirstLaunch {
            do {
                // Create default profile from current Dock state
                _ = try await stateManager.createDefaultProfile()
                stateManager.markFirstLaunchComplete()
            } catch {
                print("Error creating default profile: \(error)")
                // Continue anyway - user can create profiles manually
            }
        }
        
        isInitialized = true
    }
}
