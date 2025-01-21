import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isEditing = false
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isClearing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isEditing {
                EditProfileForm(
                    firstName: $firstName,
                    lastName: $lastName,
                    email: $email,
                    onSave: saveProfile,
                    onCancel: { isEditing = false }
                )
            } else {
                InfoRow(title: "User Identifier:", value: authManager.userIdentifier ?? "")
                InfoRow(title: "Given Name:", value: authManager.givenName ?? "Not Set")
                InfoRow(title: "Family Name:", value: authManager.familyName ?? "Not Set")
                InfoRow(title: "Email:", value: authManager.email ?? "Not Set")
                
                Button(action: {
                    firstName = authManager.givenName ?? ""
                    lastName = authManager.familyName ?? ""
                    email = authManager.email ?? ""
                    isEditing = true
                }) {
                    Text("Edit Profile")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundColor(Color("Primary"))
                        .frame(maxWidth: .infinity)
                }
            }
            
            Button(action: {
                Task {
                    await clearCacheAndReload()
                }
            }) {
                HStack {
                    if isClearing {
                        ProgressView()
                            .tint(Color("Primary"))
                            .padding(.trailing, 8)
                    }
                    Text(isClearing ? "Clearing Cache..." : "Clear Cache and Reload")
                }
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(Color("Primary"))
                .frame(maxWidth: .infinity)
            }
            .disabled(isClearing)
            
            Button("Sign Out") {
                authManager.signOut()
            }
            .font(.system(size: 23, weight: .semibold))
            .foregroundColor(Color("Secondary"))
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .alert("Profile Update", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            Task {
                await loadUserProfile()
            }
        }
    }
    
    private func clearCacheAndReload() async {
        isClearing = true
        defer { isClearing = false }
        
        do {
            // Clear the cache
            try await BuildingCacheService.shared.clearCacheOnUserRequest()
            
            // Fetch fresh data from Supabase
            let buildings = try await SupabaseService.shared.getAllBuildings()
            try await BuildingCacheService.shared.updateCache(with: buildings)
            
            // Update terms cache
            try await BuildingCacheService.shared.updateTermsCache()
            
            DispatchQueue.main.async {
                showingAlert = true
                alertMessage = "Cache cleared and data reloaded successfully!"
            }
        } catch {
            DispatchQueue.main.async {
                showingAlert = true
                alertMessage = "Failed to clear cache: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadUserProfile() async {
        guard let icloudId = authManager.userIdentifier else { return }
        
        do {
            if let user = try await SupabaseService.shared.getUser(icloudId: icloudId),
               let profile = try await SupabaseService.shared.getProfile(id: user.profileId) {
                DispatchQueue.main.async {
                    authManager.givenName = profile.firstName
                    authManager.familyName = profile.lastName
                    authManager.email = profile.email
                    
                    // If any required field is missing, show edit form
                    if profile.email == nil || profile.firstName == nil || profile.lastName == nil {
                        firstName = profile.firstName ?? ""
                        lastName = profile.lastName ?? ""
                        email = profile.email ?? ""
                        isEditing = true
                    }
                }
            } else {
                // No user/profile found, show edit form
                DispatchQueue.main.async {
                    isEditing = true
                }
            }
        } catch {
            print("Error loading profile: \(error)")
        }
    }
    
    private func saveProfile() async {
        guard let icloudId = authManager.userIdentifier else { return }
        
        do {
            let user = try await SupabaseService.shared.createOrUpdateUser(
                icloudId: icloudId,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            
            DispatchQueue.main.async {
                authManager.givenName = firstName
                authManager.familyName = lastName
                authManager.email = email
                isEditing = false
                showingAlert = true
                alertMessage = "Profile updated successfully!"
            }
        } catch {
            DispatchQueue.main.async {
                showingAlert = true
                alertMessage = "Failed to update profile: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    UserProfileView()
        .environmentObject(AuthenticationManager())
} 
