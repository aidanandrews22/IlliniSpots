import SwiftUI

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
    InfoRow(title: "Sample Title", value: "Sample Value")
} 