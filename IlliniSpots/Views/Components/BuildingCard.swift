import SwiftUI

struct BuildingCard: View {
    let buildingDetails: BuildingDetails
    let userId: UUID?
    
    var averageRating: Double {
        guard !buildingDetails.ratings.isEmpty else { return 0 }
        let sum = buildingDetails.ratings.reduce(0.0) { $0 + Double($1.rating) }
        return sum / Double(buildingDetails.ratings.count)
    }
    
    var availabilityText: String {
        if !buildingDetails.isOpen {
            return "Currently Closed"
        } else if buildingDetails.availableRooms > 0 {
            return "\(buildingDetails.availableRooms) of \(buildingDetails.totalRooms) rooms available"
        } else {
            return "No rooms available"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ImageCarousel(
                images: buildingDetails.images,
                buildingId: buildingDetails.building.id,
                userId: userId,
                isFavorite: buildingDetails.isFavorited
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(buildingDetails.building.name)
                        .font(.headline)
                    
                    Circle()
                        .fill(buildingDetails.isOpen ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Spacer()
                    
                    if !buildingDetails.ratings.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                            Text(String(format: "%.2f", averageRating))
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                }
                
                if let address = buildingDetails.building.address {
                    Text(address)
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                }
                
                if let hours = buildingDetails.building.hours {
                    Text(hours)
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Text(availabilityText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(buildingDetails.isOpen ? (buildingDetails.availableRooms > 0 ? .green : .red) : .gray)
                    
                    if buildingDetails.isOpen && buildingDetails.availableRooms > 0 {
                        Image(systemName: "door.left.hand.open")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    BuildingCard(
        buildingDetails: BuildingDetails(
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
            isOpen: true,
            totalRooms: 10,
            availableRooms: 5,
            ratings: [],
            images: [],
            isFavorited: false
        ),
        userId: nil
    )
} 