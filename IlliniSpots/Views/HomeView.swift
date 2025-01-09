import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private func calculateCardWidth(for geometry: GeometryProxy) -> CGFloat {
        let spacing: CGFloat = 16
        let horizontalPadding: CGFloat = 16 * 2
        let numberOfColumns: CGFloat = 2
        
        let availableWidth = geometry.size.width - horizontalPadding - (spacing * (numberOfColumns - 1))
        return availableWidth / numberOfColumns
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let cardWidth = calculateCardWidth(for: geometry)
                
                ScrollView {
                    ScrollViewReader { scrollProxy in
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
                                        .id(building.id)
                                        .onAppear {
                                            Task {
                                                await viewModel.ensureBuildingDataLoaded(building)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Loading Progress and Trigger
                                if viewModel.hasMoreContent {
                                    GeometryReader { loadTrigger -> Color in
                                        let frame = loadTrigger.frame(in: .named("scroll"))
                                        let triggerPoint = frame.minY - geometry.size.height
                                        
                                        if triggerPoint < 200 {
                                            Task {
                                                await viewModel.loadMoreContent()
                                            }
                                        }
                                        
                                        return Color.clear
                                    }
                                    .frame(height: 50)
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding()
                                    }
                                }
                            }
                            
                            // Loading Progress Counter
                            if viewModel.buildings.count > 0 {
                                Text("\(viewModel.buildings.count) of \(viewModel.totalBuildingCount) buildings loaded")
                                    .font(.caption)
                                    .foregroundColor(Color("Text").opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.bottom)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .coordinateSpace(name: "scroll")
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