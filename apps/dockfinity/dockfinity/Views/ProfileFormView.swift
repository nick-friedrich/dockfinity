//
//  ProfileFormView.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import SwiftUI
import SwiftData

struct ProfileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingProfiles: [Profile]
    
    @State private var name: String
    @State private var errorMessage: String?
    
    let profile: Profile?
    let onSave: (Profile) -> Void
    
    init(profile: Profile? = nil, onSave: @escaping (Profile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        _name = State(initialValue: profile?.name ?? "")
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Profile Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 150)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle(profile == nil ? "New Profile" : "Edit Profile")
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Check for duplicate names (excluding current profile if editing)
        let isDuplicate = existingProfiles.contains { existingProfile in
            existingProfile.name == trimmedName && existingProfile.id != profile?.id
        }
        
        if isDuplicate {
            errorMessage = "A profile with this name already exists"
            return
        }
        
        if let profile {
            // Edit existing profile
            profile.name = trimmedName
        } else {
            // Create new profile
            let newProfile = Profile(
                name: trimmedName,
                isDefault: false,
                sortOrder: existingProfiles.count
            )
            modelContext.insert(newProfile)
        }
        
        do {
            try modelContext.save()
            if let profile {
                onSave(profile)
            } else if let newProfile = existingProfiles.first(where: { $0.name == trimmedName }) {
                onSave(newProfile)
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
    }
}

