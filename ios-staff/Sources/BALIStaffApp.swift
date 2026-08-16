import SwiftUI

@main
struct BALIStaffApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    var body: some View {
        Group {
            if session.isLoggedIn { StaffHomeView() }
            else { OnboardingView() }
        }
        .tint(Color(red: 0.90, green: 1.0, blue: 0.38))
    }
}
