import SwiftUI

struct BuildingDetailView: View {
    let buildingDetails: BuildingDetails
    let userId: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDateTime = Date()
    @State private var roomAvailabilities: [RoomAvailability] = []
    @State private var buildingStatus: (isOpen: Bool, message: String) = (false, "")
    @State private var isLoading = true
    
    var averageRating: Double {
        guard !buildingDetails.ratings.isEmpty else { return 0 }
        let sum = buildingDetails.ratings.reduce(0.0) { $0 + Double($1.rating) }
        return sum / Double(buildingDetails.ratings.count)
    }
    
    func loadAvailabilityData() async {
        isLoading = true
        do {
            let availabilities = try await SupabaseService.shared.getRoomAvailability(
                buildingId: buildingDetails.building.id,
                date: selectedDateTime
            )
            let status = SupabaseService.shared.getBuildingAvailabilityForDate(
                buildingId: buildingDetails.building.id,
                hours: buildingDetails.building.hours,
                date: selectedDateTime
            )
            
            await MainActor.run {
                roomAvailabilities = availabilities
                buildingStatus = status
                isLoading = false
            }
        } catch {
            print("Error loading availability: \(error)")
            isLoading = false
        }
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
                    
                    // Building Status Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "door.left.hand.open")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Status")
                                    .font(.headline)
                                HStack {
                                    Circle()
                                        .fill(buildingStatus.isOpen ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(buildingStatus.message)
                                        .foregroundColor(buildingStatus.isOpen ? .green : .red)
                                        .font(.subheadline)
                                }
                            }
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
                    
                    // Room Availability Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.title2)
                            Text("Check Availability")
                                .font(.headline)
                        }
                        
                        DatePicker("Select Date & Time",
                                 selection: $selectedDateTime,
                                 displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .onChange(of: selectedDateTime) { _ in
                                Task {
                                    await loadAvailabilityData()
                                }
                            }
                        
                        if isLoading {
                            ProgressView("Loading availability...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if !buildingStatus.isOpen {
                            VStack(alignment: .center, spacing: 8) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red)
                                Text("Building is closed")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text(buildingStatus.message)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(roomAvailabilities) { room in
                                RoomAvailabilityRow(availability: room)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .background(Color("Background"))
        .task {
            await loadAvailabilityData()
        }
    }
}

struct RoomAvailabilityRow: View {
    let availability: RoomAvailability
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Room \(availability.roomNumber)")
                    .font(.headline)
                Spacer()
                StatusIndicator(status: availability.currentStatus)
            }
            
            if let event = availability.event {
                Text(event.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatusIndicator: View {
    let status: RoomAvailability.Status
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status.description)
                .font(.subheadline)
                .foregroundColor(color)
        }
    }
    
    var color: Color {
        switch status {
        case .available:
            return .green
        case .occupied:
            return .red
        case .closed:
            return .gray
        }
    }
}

#Preview {
    BuildingDetailView(
        buildingDetails: BuildingDetails(
            building: Building(
                id: 1,
                name: "Grainger Engineering Library",
                description: "A beautiful library for engineering students",
                isAvailable: true,
                address: "1301 W Springfield Ave",
                hours: "Monday: 8:00 AM - 5:00 PM",
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