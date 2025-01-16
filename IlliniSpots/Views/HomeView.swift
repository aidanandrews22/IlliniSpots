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
                            FavoritesSection(
                                favorites: viewModel.favoriteBuildingDetails,
                                cardWidth: cardWidth
                            )
                            
                            BuildingsGridSection(
                                buildings: viewModel.buildingDetails,
                                cardWidth: cardWidth,
                                isLoading: viewModel.isLoading,
                                hasMoreContent: viewModel.hasMoreContent,
                                totalCount: viewModel.totalBuildingCount,
                                onLoadMore: {
                                    Task {
                                        await viewModel.loadMoreContent()
                                    }
                                }
                            )
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