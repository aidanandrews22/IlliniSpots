import SwiftUI
import AuthenticationServices

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
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Background"))
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
} 