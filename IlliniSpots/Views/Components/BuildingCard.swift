import SwiftUI

struct BuildingCard: View {
    let building: Building
    let imageURL: String?
    let isCompact: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(Color.gray.opacity(0.2))
                }
                .frame(width: isCompact ? 200 : nil, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.2))
                    .frame(width: isCompact ? 200 : nil, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text(building.name)
                .font(.headline)
                .foregroundColor(Color("Text"))
                .lineLimit(2)
                .padding(.horizontal, 4)
        }
        .frame(width: isCompact ? 200 : nil)
        .background(Color("Background"))
    }
}

#Preview {
    BuildingCard(
        building: Building(
            id: 1,
            name: "Grainger Engineering Library",
            description: nil,
            isAvailable: true,
            address: nil,
            hours: nil,
            favorites: 0,
            commentCount: 0,
            sortedId: 1
        ),
        imageURL: nil,
        isCompact: true
    )
} 