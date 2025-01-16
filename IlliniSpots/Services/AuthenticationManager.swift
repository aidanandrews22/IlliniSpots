import SwiftUI
import AuthenticationServices
import os.log

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userIdentifier: String?
    @Published var givenName: String?
    @Published var familyName: String?
    @Published var email: String?
    @Published private(set) var userId: UUID?
    private var logger = Logger(subsystem: "com.illinistudy.app", category: "LoginView")
    
    init() {
        // Check for existing sign in
        userIdentifier = KeychainItem.currentUserIdentifier
        isAuthenticated = userIdentifier != nil
    }
    
    func checkCredentialState() {
        // Only check if we have a stored identifier
        if let userIdentifier = KeychainItem.currentUserIdentifier {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            appleIDProvider.getCredentialState(forUserID: userIdentifier) { [weak self] (credentialState, error) in
                DispatchQueue.main.async {
                    switch credentialState {
                    case .authorized:
                        // The Apple ID credential is valid
                        self?.isAuthenticated = true
                        // Check Supabase for user data
                        Task {
                            await self?.syncUserWithSupabase()
                        }
                    case .revoked, .notFound:
                        // The Apple ID credential is either revoked or was not found
                        self?.signOut()
                    default:
                        break
                    }
                }
            }
        } else {
            // No stored identifier, ensure we're signed out
            signOut()
        }
    }
    
    func signOut() {
        KeychainItem.deleteUserIdentifierFromKeychain()
        isAuthenticated = false
        userIdentifier = nil
        givenName = nil
        familyName = nil
        email = nil
        userId = nil
    }
    
    private func syncUserWithSupabase() async {
        guard let icloudId = userIdentifier else { return }
        
        do {
            // Create or get existing user and profile
            let user = try await SupabaseService.shared.createOrUpdateUser(
                icloudId: icloudId,
                email: email,
                firstName: givenName,
                lastName: familyName
            )
            
            // Update userId on main thread
            await MainActor.run {
                self.userId = user.profileId
            }
        } catch {
            logger.error("Failed to sync user with Supabase: \(error.localizedDescription)")
        }
    }
    
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            switch authorization.credential {
            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                let userIdentifier = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                let email = appleIDCredential.email
                logger.info("User \(userIdentifier) signed in")
                logger.info("FullName, email: \(fullName?.givenName ?? "nil") \(fullName?.familyName ?? "nil"), \(email ?? "nil")")
                
                // Store user identifier in keychain
                do {
                    try KeychainItem.saveUserIdentifier(userIdentifier)
                } catch {
                    print("Unable to save userIdentifier to keychain:", error)
                }
                
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    self.userIdentifier = userIdentifier
                    self.givenName = fullName?.givenName
                    self.familyName = fullName?.familyName
                    self.email = email
                    
                    // Sync with Supabase
                    Task {
                        await self.syncUserWithSupabase()
                    }
                }
                
            default:
                break
            }
        case .failure(let error):
            print("Authorization failed:", error)
        }
    }
} 