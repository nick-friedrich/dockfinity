//
//  UpdateNotificationView.swift
//  dockfinity
//
//  View to display update notification
//

import SwiftUI

struct UpdateNotificationView: View {
    @ObservedObject var updateChecker: UpdateChecker
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            // Title
            Text("Update Available")
                .font(.title)
                .fontWeight(.bold)
            
            // Version info
            VStack(spacing: 8) {
                HStack {
                    Text("Current Version:")
                        .foregroundColor(.secondary)
                    Text(updateChecker.currentVersion)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Latest Version:")
                        .foregroundColor(.secondary)
                    Text(updateChecker.latestVersion)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .font(.body)
            
            Text("A new version of DockFinity is available!")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Buttons
            HStack(spacing: 12) {
                Button("Later") {
                    updateChecker.dismissUpdate()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Download Update") {
                    updateChecker.openReleasePage()
                    updateChecker.dismissUpdate()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 400)
    }
}

#Preview {
    UpdateNotificationView(updateChecker: UpdateChecker.shared)
}

