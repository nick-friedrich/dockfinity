//
//  SettingsView.swift
//  dockfinity
//
//  Settings window for app preferences
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @StateObject private var updateChecker = UpdateChecker.shared
    @State private var showingUpdateResult = false
    @State private var updateMessage = ""
    @State private var localUpdateAvailable = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $appSettings.launchAtLogin)
                
                Text("Automatically start DockFinity when you log in to your Mac.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("General")
            }
            
            Section {
                Toggle("Show in Dock", isOn: $appSettings.showInDock)
                
                Text("When disabled, DockFinity will only appear in the menu bar. You can still access the main window from the menu bar icon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("Appearance")
            }
            
            Section {
                HStack {
                    Text("Current Version:")
                        .foregroundColor(.secondary)
                    Text(updateChecker.currentVersion)
                        .fontWeight(.medium)
                }
                
                if let lastCheck = updateChecker.lastCheckDate {
                    HStack {
                        Text("Last Check:")
                            .foregroundColor(.secondary)
                        Text(lastCheck, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    Task {
                        await checkForUpdates()
                    }
                }) {
                    HStack {
                        Text("Check for Updates")
                        if updateChecker.isChecking {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                .disabled(updateChecker.isChecking)
                
                Text("DockFinity will automatically check for updates when launched.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("Updates")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .navigationTitle("Settings")
        .alert("Update Check", isPresented: $showingUpdateResult) {
            if localUpdateAvailable {
                Button("Download") {
                    updateChecker.openReleasePage()
                }
                Button("Later", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            Text(updateMessage)
        }
    }
    
    private func checkForUpdates() async {
        // Check without triggering the global notification sheet
        await updateChecker.checkForUpdates(silent: false, notify: false)
        
        await MainActor.run {
            let hasUpdate = updateChecker.compareVersions(
                current: updateChecker.currentVersion, 
                latest: updateChecker.latestVersion
            )
            
            localUpdateAvailable = hasUpdate
            
            if hasUpdate {
                updateMessage = "Version \(updateChecker.latestVersion) is available!"
            } else {
                updateMessage = "You're running the latest version."
            }
            showingUpdateResult = true
        }
    }
}

#Preview {
    SettingsView(appSettings: AppSettings.shared)
}

