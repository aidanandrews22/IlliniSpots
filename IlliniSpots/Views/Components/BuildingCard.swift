import SwiftUI

struct BuildingCard: View {
    let building: Building
    let imageURL: String?
    let isCompact: Bool
    
    // Fixed dimensions for the card
    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 220
    private let imageHeight: CGFloat = 150
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image container with fixed dimensions
            if let imageURL = imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(Color.gray.opacity(0.2))
                }
                .frame(width: cardWidth, height: imageHeight)
                .clipped()
            } else {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.2))
                    .frame(width: cardWidth, height: imageHeight)
            }
            
            // Text container with fixed height
            Text(building.name)
                .font(.headline)
                .foregroundColor(Color("Text"))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: cardWidth - 16)
                .padding(.horizontal, 8)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color("Background"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2, y: 1)
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