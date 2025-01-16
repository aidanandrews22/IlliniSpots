import SwiftUI

struct FavoritesSection: View {
    let favorites: [BuildingDetails]
    let cardWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Favorites")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("Text"))
                .padding(.horizontal)
            
            if favorites.isEmpty {
                Text("Add some favorites to see them here!")
                    .foregroundColor(Color("Text").opacity(0.7))
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(favorites, id: \.building.id) { details in
                            BuildingCard(
                                buildingDetails: details,
                                userId: nil
                            )
                            .frame(width: cardWidth)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
} 