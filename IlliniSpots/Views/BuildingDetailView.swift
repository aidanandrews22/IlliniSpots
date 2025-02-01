import SwiftUI

struct BuildingDetailView: View {
    let buildingDetails: BuildingDetails
    let userId: UUID?
    @Environment(\.dismiss) private var dismiss
    
    var averageRating: Double {
        guard !buildingDetails.ratings.isEmpty else { return 0 }
        let sum = buildingDetails.ratings.reduce(0.0) { $0 + Double($1.rating) }
        return sum / Double(buildingDetails.ratings.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Image Carousel
                ZStack(alignment: .top) {
                    ImageCarousel(
                        images: buildingDetails.images,
                        buildingId: buildingDetails.building.id,
                        userId: userId,
                        isFavorite: buildingDetails.isFavorited
                    )
                    .frame(height: 300)
                    
                    // Back Button
                    HStack {
                        Button(action: { dismiss() }) {
                            Circle()
                                .fill(.white)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(.black)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .shadow(radius: 4)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(buildingDetails.building.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let address = buildingDetails.building.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        if !buildingDetails.ratings.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.2f", averageRating))
                                    .fontWeight(.semibold)
                                Text("(\(buildingDetails.ratings.count) reviews)")
                                    .foregroundColor(.gray)
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    Divider()
                    
                    // Availability Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "door.left.hand.open")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Availability")
                                    .font(.headline)
                                HStack {
                                    Circle()
                                        .fill(buildingDetails.isOpen ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(buildingDetails.isOpen ? "Open" : "Closed")
                                        .foregroundColor(buildingDetails.isOpen ? .green : .red)
                                        .font(.subheadline)
                                }
                            }
                        }
                        
                        if buildingDetails.isOpen {
                            Text("\(buildingDetails.availableRooms) of \(buildingDetails.totalRooms) rooms available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Hours Section
                    if let hours = buildingDetails.building.hours {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.title2)
                                Text("Hours")
                                    .font(.headline)
                            }
                            
                            Text(hours)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                    }
                    
                    // Description Section
                    if let description = buildingDetails.building.description {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.title2)
                                Text("About")
                                    .font(.headline)
                            }
                            
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                    }
                    
                    // Room List Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                            Text("Rooms")
                                .font(.headline)
                        }
                        
                        if buildingDetails.totalRooms > 0 {
                            Text("This building has \(buildingDetails.totalRooms) rooms in total.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if buildingDetails.isOpen {
                                Text("\(buildingDetails.availableRooms) rooms are currently available.")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            } else {
                                Text("Building is currently closed.")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        } else {
                            Text("No room information available.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .background(Color("Background"))
    }
}