import SwiftUI

@main
struct BronzlaWatchApp: App {
    @State private var model = WatchUVModel()

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environment(model)
        }
    }
}
