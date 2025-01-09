//
//  ContentView.swift
//  Temp
//
//  Created by Aidan Andrews on 1/7/25.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            Group {
                if authManager.isAuthenticated {
                    UserProfileView()
                } else {
                    SignInPromptView()
                }
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
        .accentColor(Color("Primary"))
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to IlliniSpots")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color("Text"))
                    .padding()
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Background"))
            .navigationTitle("Home")
        }
    }
}

struct SignInPromptView: View {
    @State private var showingLogin = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundColor(Color("Primary"))
                    .padding()
                
                Text("Sign in Required")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color("Text"))
                
                Text("Please sign in to access your profile")
                    .font(.system(size: 16))
                    .foregroundColor(Color("Text"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    showingLogin = true
                }) {
                    Text("Sign In")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 45)
                        .background(Color("Primary"))
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Background"))
            .navigationTitle("Profile")
            .sheet(isPresented: $showingLogin) {
                LoginView()
            }
        }
    }
}

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                Spacer()
                    .frame(height: 20)
                
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color("Primary"), lineWidth: 2)
                    )
                    .shadow(radius: 5)
                
                Text("IlliniSpots")
                    .font(.system(size: 55, weight: .heavy))
                    .foregroundColor(Color("Text"))
                    .padding(.bottom, 10)
                
                Spacer()
                
                VStack(spacing: 16) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            authManager.handleSignInWithAppleCompletion(result)
                            dismiss()
                        }
                    )
                    .frame(height: 44)
                    
//                    Button("Continue without signing in") {
//                        dismiss()
//                    }
//                    .font(.system(size: 18, weight: .semibold))
//                    .foregroundColor(Color("Primary"))
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Background"))
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct UserProfileView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isEditing = false
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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

struct EditProfileForm: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    let onSave: () async -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Edit Profile")
                .font(.title)
                .foregroundColor(Color("Text"))
            
            TextField("First Name", text: $firstName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Last Name", text: $lastName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(Color("Primary"))
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await onSave()
                    }
                }
                .foregroundColor(Color("Primary"))
            }
            .padding(.top)
        }
        .padding()
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 7.5) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color("Text"))
            Text(value)
                .font(.system(size: 22))
                .foregroundColor(Color("Text"))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
