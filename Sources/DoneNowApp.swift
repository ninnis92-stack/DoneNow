import SwiftUI

@main
struct DoneNowApp: App {
    @StateObject private var ads = AdMobCoordinator.shared

    init() { SessionMusicPreferences.migrate() }

    var body: some Scene {
        WindowGroup {
            MainFocusView()
                .environmentObject(ads)
                .task { ads.start() }
        }
    }
}
