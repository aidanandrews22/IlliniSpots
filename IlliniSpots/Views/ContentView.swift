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

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
} 