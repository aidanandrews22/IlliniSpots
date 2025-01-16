import SwiftUI

struct ImageCarousel: View {
    let images: [BuildingImage]
    let buildingId: Int64
    let userId: UUID?
    @State private var currentIndex = 0
    @State private var isFavorite: Bool
    
    init(images: [BuildingImage], buildingId: Int64, userId: UUID?, isFavorite: Bool = false) {
        self.images = images
        self.buildingId = buildingId
        self.userId = userId
        self._isFavorite = State(initialValue: isFavorite)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentIndex) {
                ForEach(0..<images.count, id: \.self) { index in
                    AsyncImage(url: URL(string: images[index].url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack {
                HStack {
                    Spacer()
                    if let userId = userId {
                        Button(action: {
                            Task {
                                do {
                                    try await SupabaseService.shared.toggleBuildingFavorite(userId: userId, buildingId: buildingId)
                                    isFavorite.toggle()
                                } catch {
                                    print("Error toggling favorite: \(error)")
                                }
                            }
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : Color(.darkGray))
                                .font(.system(size: 22, weight: .semibold))
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.95)))
                                .shadow(radius: 2)
                        }
                        .padding(16)
                    }
                }
                .padding(.top, 8)
                
                Spacer()
                
                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(currentIndex == index ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
} 