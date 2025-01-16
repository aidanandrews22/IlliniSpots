import SwiftUI

struct SearchBarView: View {
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            Text("Search buildings")
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(25)
        .padding(.horizontal)
        .padding(.top, 8)
    }
} 