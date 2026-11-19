import UIKit
import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13.0, *) {
            window.rootViewController = UIHostingController(rootView: RootView().environmentObject(Store()))
        } else {
            window.rootViewController = UIViewController()
            window.rootViewController?.view.backgroundColor = .white
        }
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}

@available(iOS 13.0, *)
struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView().tabItem { Image(systemName: "house"); Text("Feed") }.tag(0)
            FYPView().tabItem { Image(systemName: "sparkles"); Text("For You") }.tag(1)
            ComposeView().tabItem { Image(systemName: "square.and.pencil"); Text("Post") }.tag(2)
            AccountsView().tabItem { Image(systemName: "person.2"); Text("Accounts") }.tag(3)
        }
    }
}