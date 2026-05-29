#if canImport(AppFeature)
import AppFeature
#endif
import FirebaseCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import SwiftUI
import UIKit

@main
struct FitnessCoachApp: App {
    private let dependencies: AppDependencies

    init() {
        FirebaseApp.configure()
        Self.configureAppearance()

#if targetEnvironment(simulator)
        if CommandLine.arguments.contains("--AutoSignIn") {
            self.dependencies = .previewSignedIn()
        } else {
            self.dependencies = .live()
        }
#else
        self.dependencies = .live()
#endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
    }

    // MARK: - Always-Dark UIKit appearance

    private static func configureAppearance() {
        // Tab Bar — deep dark
        let tabBarBG = UIColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1.0)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = tabBarBG
        tabAppearance.shadowImage = UIImage()
        tabAppearance.shadowColor = UIColor.white.withAlphaComponent(0.05)

        let normalItem = tabAppearance.stackedLayoutAppearance
        normalItem.normal.iconColor    = UIColor(white: 0.55, alpha: 1)
        normalItem.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 0.55, alpha: 1)]
        normalItem.selected.iconColor  = UIColor(red: 0.00, green: 0.898, blue: 0.627, alpha: 1) // accent
        normalItem.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 0.00, green: 0.898, blue: 0.627, alpha: 1)]
        tabAppearance.stackedLayoutAppearance = normalItem

        UITabBar.appearance().standardAppearance   = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Navigation Bar — same dark surface
        let navBG = UIColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1.0)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = navBG
        navAppearance.shadowColor     = UIColor.white.withAlphaComponent(0.05)
        navAppearance.titleTextAttributes       = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes  = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor            = UIColor(red: 0.00, green: 0.898, blue: 0.627, alpha: 1)
    }
}
