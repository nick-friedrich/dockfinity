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
    
    @State private var isInitialized = false

    var body: some Scene {
        WindowGroup {
            if isInitialized {
                ContentView(modelContext: sharedModelContainer.mainContext)
                    .modelContainer(sharedModelContainer)
            } else {
                ProgressView("Initializing DockFinity...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await initializeApp()
                    }
            }
        }
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
