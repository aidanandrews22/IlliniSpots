import SwiftUI

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

#Preview {
    SignInPromptView()
} 