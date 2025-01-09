import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private func calculateCardWidth(for geometry: GeometryProxy) -> CGFloat {
        let spacing: CGFloat = 16
        let horizontalPadding: CGFloat = 16 * 2
        let numberOfColumns: CGFloat = 2
        
        // Calculate available width after subtracting padding and spacing
        let availableWidth = geometry.size.width - horizontalPadding - (spacing * (numberOfColumns - 1))
        // Divide by number of columns to get card width
        return availableWidth / numberOfColumns
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let cardWidth = calculateCardWidth(for: geometry)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Favorites Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Favorites")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color("Text"))
                                .padding(.horizontal)
                            
                            if viewModel.favoriteBuildings.isEmpty {
                                Text("Add some favorites to see them here!")
                                    .foregroundColor(Color("Text").opacity(0.7))
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(viewModel.favoriteBuildings) { building in
                                            BuildingCard(
                                                building: building,
                                                imageURL: viewModel.buildingImages[building.id],
                                                isCompact: true,
                                                cardWidth: cardWidth
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // All Buildings Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Buildings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color("Text"))
                                .padding(.horizontal)
                            
                            // Filter Buttons
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(["All", "Available", "Libraries", "Academic"], id: \.self) { filter in
                                        Button(action: {
                                            // Filter action to be implemented
                                        }) {
                                            Text(filter)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color("Primary").opacity(0.1))
                                                .foregroundColor(Color("Primary"))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Buildings Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(viewModel.buildings) { building in
                                    BuildingCard(
                                        building: building,
                                        imageURL: viewModel.buildingImages[building.id],
                                        isCompact: false,
                                        cardWidth: cardWidth
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color("Background"))
                .navigationTitle("Home")
                .task {
                    await viewModel.loadBuildings()
                }
            }
        }
    }
}

#Preview {
    HomeView()
} 