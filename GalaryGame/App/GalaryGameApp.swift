import SwiftUI
import SwiftData

@main
struct GalaryGameApp: App {

    /// Single SwiftData container for all persisted game state.
    let container: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            CleanupEvent.self,
            Achievement.self,
            Quest.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
