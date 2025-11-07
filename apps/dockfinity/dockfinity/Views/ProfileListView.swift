//
//  ProfileListView.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import SwiftUI
import SwiftData

struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]
    
    @Binding var selectedProfile: Profile?
    @Binding var showingNewProfile: Bool
    
    let currentProfileID: UUID?
    let onApply: @MainActor @Sendable (Profile) async -> Void
    let onRefresh: @MainActor @Sendable (Profile) async -> Void
    let onDuplicate: @MainActor @Sendable (Profile) -> Void
    
    @State private var profileToEdit: Profile?
    @State private var applyingProfile: Profile?
    @State private var deletingProfile: Profile?
    
    var body: some View {
        List(selection: $selectedProfile) {
            ForEach(profiles) { profile in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(profile.name)
                                .font(.headline)
                            
                            if profile.isDefault {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Text("\(profile.items.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if profile.id == currentProfileID {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    if applyingProfile?.id == profile.id {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .tag(profile)
                .contextMenu {
                    Button("Apply Profile") {
                        Task {
                            applyingProfile = profile
                            await onApply(profile)
                            applyingProfile = nil
                        }
                    }
                    
                    Button("Refresh from Dock") {
                        Task {
                            await onRefresh(profile)
                        }
                    }
                    
                    Divider()
                    
                    Button("Duplicate") {
                        onDuplicate(profile)
                    }
                    
                    Button("Rename") {
                        profileToEdit = profile
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        deletingProfile = profile
                    }
                }
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewProfile = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
            }
        }
        .sheet(item: $profileToEdit) { profile in
            NavigationStack {
                ProfileFormView(profile: profile) { _ in
                    // Profile updated
                }
            }
        }
        .alert("Delete Profile", isPresented: .constant(deletingProfile != nil), presenting: deletingProfile) { profile in
            Button("Cancel", role: .cancel) {
                deletingProfile = nil
            }
            Button("Delete", role: .destructive) {
                deleteProfile(profile)
            }
        } message: { profile in
            Text("Are you sure you want to delete '\(profile.name)'? This action cannot be undone.")
        }
    }
    
    private func deleteProfile(_ profile: Profile) {
        withAnimation {
            if selectedProfile?.id == profile.id {
                selectedProfile = nil
            }
            modelContext.delete(profile)
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to delete profile: \(error)")
            }
        }
        deletingProfile = nil
    }
}
