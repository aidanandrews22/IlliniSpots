import SwiftUI

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

#Preview {
    HomeView()
} 