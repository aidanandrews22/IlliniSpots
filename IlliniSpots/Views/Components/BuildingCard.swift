import SwiftUI

struct BuildingCard: View {
    let building: Building
    let imageURL: String?
    let isCompact: Bool
    let cardWidth: CGFloat
    
    // Fixed aspect ratios
    private let cardAspectRatio: CGFloat = 220/200 // height/width ratio from original dimensions
    private let imageAspectRatio: CGFloat = 150/200 // height/width ratio from original dimensions
    
    private var cardHeight: CGFloat {
        cardWidth * cardAspectRatio
    }
    
    private var imageHeight: CGFloat {
        cardWidth * imageAspectRatio
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Image container with dynamic dimensions
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
            
            // Text container
            Text(building.name)
                .font(.headline)
                .foregroundColor(Color("Text"))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: cardWidth - 16)
                .padding(.horizontal, 8)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .top)
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
        isCompact: true,
        cardWidth: 200
    )
} 