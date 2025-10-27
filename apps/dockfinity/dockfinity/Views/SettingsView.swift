//
//  SettingsView.swift
//  dockfinity
//
//  Settings window for app preferences
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    
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
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView(appSettings: AppSettings.shared)
}

