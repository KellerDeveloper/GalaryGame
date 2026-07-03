import SwiftUI
import SwiftData

/// Decides between onboarding and the main experience, and owns the shared
/// `GameStore` + `PhotoLibraryService`.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var store: GameStore?
    @State private var photos = PhotoLibraryService()

    var body: some View {
        Group {
            if let store {
                switch photos.authState {
                case .authorized, .limited:
                    MainTabView(store: store, photos: photos)
                default:
                    OnboardingView(photos: photos)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if store == nil { store = GameStore(modelContext: modelContext) }
            photos.refreshAuthState()
        }
    }
}

/// The primary tab-based navigation.
struct MainTabView: View {
    let store: GameStore
    let photos: PhotoLibraryService

    var body: some View {
        TabView {
            DashboardView(store: store, photos: photos)
                .tabItem { Label("Порядок", systemImage: "chart.pie.fill") }

            FilesView(store: store)
                .tabItem { Label("Файлы", systemImage: "folder.fill") }

            AchievementsView(store: store)
                .tabItem { Label("Награды", systemImage: "trophy.fill") }

            GardenView(store: store)
                .tabItem { Label("Сад", systemImage: "leaf.fill") }
        }
        .tint(Theme.accent)
    }
}
